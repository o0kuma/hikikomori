package main

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
	"gorm.io/gorm"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

type signupRequest struct {
	InviteCode  string `json:"invite_code" binding:"required"`
	DisplayName string `json:"display_name" binding:"required"`
}

type sendMessageRequest struct {
	SenderID   uint       `json:"sender_id" binding:"required"`
	Text       string     `json:"text" binding:"required"`
	SenderMode SenderMode `json:"sender_mode"`
	// Approved represents the human tapping "승인" on an L1 draft, or on an
	// L2 draft outside the whitelist (PRD.md §2.2). Ignored for
	// human-authored messages.
	Approved bool `json:"approved"`
}

type updateTwinSettingsRequest struct {
	AutonomyLevel AutonomyLevel `json:"autonomy_level" binding:"required"`
}

type draftMessageRequest struct {
	ContextLines  []string `json:"context_lines" binding:"required"`
	StyleExamples []string `json:"style_examples"`
	History       []string `json:"history"`
	K             int      `json:"k"`
}

func setupRouter(db *gorm.DB, relay *ConnectionManager, ai *AIServiceClient) *gin.Engine {
	r := gin.Default()

	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	r.POST("/auth/signup", func(c *gin.Context) {
		var req signupRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"detail": err.Error()})
			return
		}

		var existing User
		if err := db.Where("invite_code = ?", req.InviteCode).First(&existing).Error; err == nil {
			c.JSON(http.StatusConflict, gin.H{"detail": "invite_code already used"})
			return
		}

		user := User{InviteCode: req.InviteCode, DisplayName: req.DisplayName}
		if err := db.Create(&user).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"detail": err.Error()})
			return
		}
		db.Create(&TwinSettings{UserID: user.ID, AutonomyLevel: AutonomyL0})

		c.JSON(http.StatusOK, gin.H{"id": user.ID, "display_name": user.DisplayName})
	})

	r.POST("/conversations/:id/messages", func(c *gin.Context) {
		convID, ok := parseUintParam(c, "id")
		if !ok {
			return
		}

		var conversation Conversation
		if err := db.First(&conversation, convID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"detail": "conversation not found"})
			return
		}

		var req sendMessageRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"detail": err.Error()})
			return
		}
		if req.SenderMode == "" {
			req.SenderMode = SenderHuman
		}

		// Hard gate: a twin-authored send is an unattended action, so it
		// must clear escalation_filter regardless of how it got here --
		// this is the one chokepoint every twin auto-send passes through,
		// so no client or upstream path can bypass it (AGENTS.md absolute
		// safety invariants). Human-authored messages are the human's own
		// words and are never gated. On any doubt (AI service unreachable
		// or erroring) we fail closed and block the send. Escalation is
		// checked before autonomy level, and applies regardless of level or
		// whitelist match -- L2 auto-send never overrides it.
		if req.SenderMode == SenderTwin {
			result, err := ai.checkEscalation(req.Text)
			if err != nil {
				c.JSON(http.StatusBadGateway, gin.H{"detail": "escalation gate unavailable, twin send blocked: " + err.Error()})
				return
			}
			if result.Escalate {
				db.Create(&EscalationLog{
					UserID:         req.SenderID,
					ConversationID: convID,
					Reason:         result.Reason,
					MessageSnippet: req.Text,
				})
				c.JSON(http.StatusForbidden, gin.H{"detail": "escalated", "reason": result.Reason})
				return
			}

			// Autonomy gate (PRD.md §2.1/§2.2, tech-design.md §3): missing
			// settings fail closed to L0, the documented default.
			level := AutonomyL0
			var settings TwinSettings
			if err := db.Where("user_id = ?", req.SenderID).First(&settings).Error; err == nil {
				level = settings.AutonomyLevel
			}

			switch level {
			case AutonomyL0:
				c.JSON(http.StatusForbidden, gin.H{"detail": "L0(비서 모드)에서는 분신 자동 발송이 허용되지 않습니다 -- 초안만 생성하고 사람이 직접 보내세요"})
				return
			case AutonomyL1:
				if !req.Approved {
					c.JSON(http.StatusForbidden, gin.H{"detail": "L1은 발송 전 사용자 승인이 필요합니다"})
					return
				}
			case AutonomyL2:
				if !req.Approved && !whitelistMatches(db, req.SenderID, req.Text) {
					c.JSON(http.StatusForbidden, gin.H{"detail": "화이트리스트에 없는 주제는 L1과 동일하게 사용자 승인이 필요합니다"})
					return
				}
			default:
				c.JSON(http.StatusForbidden, gin.H{"detail": "알 수 없는 자율성 레벨이라 발송을 차단합니다"})
				return
			}
		}

		message := Message{
			ConversationID: convID,
			SenderID:       req.SenderID,
			SenderMode:     req.SenderMode,
			Text:           req.Text,
		}
		if err := db.Create(&message).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"detail": err.Error()})
			return
		}

		relay.broadcast(convID, gin.H{
			"id":          message.ID,
			"sender_id":   message.SenderID,
			"sender_mode": message.SenderMode,
			"text":        message.Text,
		})

		c.JSON(http.StatusOK, gin.H{"id": message.ID})
	})

	r.POST("/conversations/:id/draft", func(c *gin.Context) {
		convID, ok := parseUintParam(c, "id")
		if !ok {
			return
		}

		var conversation Conversation
		if err := db.First(&conversation, convID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"detail": "conversation not found"})
			return
		}

		var req draftMessageRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"detail": err.Error()})
			return
		}
		if len(req.StyleExamples) == 0 && len(req.History) == 0 {
			c.JSON(http.StatusBadRequest, gin.H{"detail": "provide style_examples or history"})
			return
		}

		// EscalationLog persistence (sender's post-hoc notification + undo
		// trail) is a separate checklist item -- roadmap.md Phase 1 §2.2
		// "사후 알림 + 되돌리기 로그 스키마/API". This endpoint only proxies
		// to the AI service for now.
		result, err := ai.requestDraft(draftRequest{
			ContextLines:  req.ContextLines,
			StyleExamples: req.StyleExamples,
			History:       req.History,
			K:             req.K,
		})
		if err != nil {
			c.JSON(http.StatusBadGateway, gin.H{"detail": err.Error()})
			return
		}

		c.JSON(http.StatusOK, gin.H{"status": result.Status, "text": result.Text})
	})

	r.PATCH("/users/:id/twin-settings", func(c *gin.Context) {
		userID, ok := parseUintParam(c, "id")
		if !ok {
			return
		}

		var req updateTwinSettingsRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"detail": err.Error()})
			return
		}
		if req.AutonomyLevel != AutonomyL0 && req.AutonomyLevel != AutonomyL1 && req.AutonomyLevel != AutonomyL2 {
			c.JSON(http.StatusBadRequest, gin.H{"detail": "autonomy_level must be one of L0, L1, L2"})
			return
		}

		var settings TwinSettings
		if err := db.Where("user_id = ?", userID).First(&settings).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"detail": "twin settings not found for user"})
			return
		}
		settings.AutonomyLevel = req.AutonomyLevel
		if err := db.Save(&settings).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"detail": err.Error()})
			return
		}

		c.JSON(http.StatusOK, gin.H{"user_id": userID, "autonomy_level": settings.AutonomyLevel})
	})

	r.DELETE("/users/:id", func(c *gin.Context) {
		userID, ok := parseUintParam(c, "id")
		if !ok {
			return
		}

		var user User
		if err := db.First(&user, userID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"detail": "user not found"})
			return
		}

		// Right-to-erasure ("사용자가 언제든 초기화 가능", tech-design.md §5):
		// wipes every row this user's ID appears on. Real chat history lives
		// on-device first (tech-design.md §2/§5) -- the server only ever held
		// a minimal relay copy, so deleting it here is not a partial erasure.
		var messagesDeleted, escalationLogsDeleted int64
		err := db.Transaction(func(tx *gorm.DB) error {
			if res := tx.Where("user_id = ?", userID).Delete(&TwinSettings{}); res.Error != nil {
				return res.Error
			}
			if res := tx.Where("user_id = ?", userID).Delete(&WhitelistRule{}); res.Error != nil {
				return res.Error
			}
			if res := tx.Where("owner_user_id = ?", userID).Delete(&Contact{}); res.Error != nil {
				return res.Error
			}
			if res := tx.Where("user_id = ?", userID).Delete(&ConversationParticipant{}); res.Error != nil {
				return res.Error
			}
			res := tx.Where("sender_id = ?", userID).Delete(&Message{})
			if res.Error != nil {
				return res.Error
			}
			messagesDeleted = res.RowsAffected
			res = tx.Where("user_id = ?", userID).Delete(&EscalationLog{})
			if res.Error != nil {
				return res.Error
			}
			escalationLogsDeleted = res.RowsAffected
			return tx.Delete(&user).Error
		})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"detail": err.Error()})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"deleted_user_id":         userID,
			"messages_deleted":        messagesDeleted,
			"escalation_logs_deleted": escalationLogsDeleted,
		})
	})

	r.GET("/ws/conversations/:id", func(c *gin.Context) {
		convID, ok := parseUintParam(c, "id")
		if !ok {
			return
		}

		conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
		if err != nil {
			return
		}
		defer conn.Close()

		relay.add(convID, conn)
		defer relay.remove(convID, conn)

		for {
			if _, _, err := conn.ReadMessage(); err != nil {
				break
			}
		}
	})

	return r
}

// whitelistMatches is a v1-minimal check: any of the user's WhitelistRule
// keywords appearing as a substring of the message text counts as a match.
// It intentionally ignores WhitelistRule.ContactID (per-counterpart
// whitelisting) because conversations aren't yet linked to a Contact row --
// that link needs its own design pass once the client's contact model
// exists, so this only supports the "any counterpart" case for now.
func whitelistMatches(db *gorm.DB, userID uint, text string) bool {
	var rules []WhitelistRule
	db.Where("user_id = ?", userID).Find(&rules)
	for _, rule := range rules {
		if strings.Contains(text, rule.TopicKeyword) {
			return true
		}
	}
	return false
}

func parseUintParam(c *gin.Context, name string) (uint, bool) {
	id, err := strconv.ParseUint(c.Param(name), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"detail": name + " must be a positive integer"})
		return 0, false
	}
	return uint(id), true
}

func main() {
	db := openDB()
	relay := newConnectionManager()
	ai := newAIServiceClient()
	r := setupRouter(db, relay, ai)
	r.Run(":8080")
}

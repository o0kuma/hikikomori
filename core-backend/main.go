package main

import (
	"net/http"
	"strconv"

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
		// or erroring) we fail closed and block the send.
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

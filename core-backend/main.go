package main

import (
	"crypto/rand"
	"encoding/hex"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

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

type createWhitelistRuleRequest struct {
	ContactID    *uint  `json:"contact_id"`
	TopicKeyword string `json:"topic_keyword" binding:"required"`
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

	registerA1A2Routes(r, db)
	registerBRoutes(r, db)
	registerInviteOpsRoutes(r, db)

	r.GET("/admin/metrics", func(c *gin.Context) {
		if !requireAdmin(c) {
			return
		}
		// v1-minimal (roadmap.md §2.6): only counts honestly derivable from
		// the current schema. Draft-generation latency and AI-service error
		// rate need a request-timing/logging layer that doesn't exist yet --
		// not fabricated here, left for that future work.
		var usersTotal, humanMessages, twinMessages, escalationsTotal int64
		var conversationsTotal, conversationsVetoed, invitesMinted, invitesUsed int64
		db.Model(&User{}).Count(&usersTotal)
		db.Model(&Message{}).Where("sender_mode = ?", SenderHuman).Count(&humanMessages)
		db.Model(&Message{}).Where("sender_mode = ?", SenderTwin).Count(&twinMessages)
		db.Model(&EscalationLog{}).Count(&escalationsTotal)
		db.Model(&Conversation{}).Count(&conversationsTotal)
		db.Model(&Conversation{}).Where("twin_disabled_by_peer = ?", true).Count(&conversationsVetoed)
		db.Model(&InviteCode{}).Count(&invitesMinted)
		db.Model(&InviteCode{}).Where("used_at IS NOT NULL").Count(&invitesUsed)

		type reasonCount struct {
			Reason string
			Count  int64
		}
		var reasonCounts []reasonCount
		db.Model(&EscalationLog{}).Select("reason, count(*) as count").Group("reason").Scan(&reasonCounts)
		escalationsByReason := map[string]int64{}
		for _, rc := range reasonCounts {
			escalationsByReason[rc.Reason] = rc.Count
		}

		var peerVetoRate float64
		if conversationsTotal > 0 {
			peerVetoRate = float64(conversationsVetoed) / float64(conversationsTotal)
		}

		rt := runtimeMetrics.snapshot()
		c.JSON(http.StatusOK, gin.H{
			"users_total":           usersTotal,
			"messages_human_total":  humanMessages,
			"messages_twin_total":   twinMessages,
			"escalations_total":     escalationsTotal,
			"escalations_by_reason": escalationsByReason,
			"conversations_total":   conversationsTotal,
			"conversations_vetoed":  conversationsVetoed,
			// Approximates vision.md's "와카뷰 거부율" metric at conversation
			// granularity (vetoed conversations / all conversations) --
			// vision.md doesn't pin down the exact denominator, so treat
			// this as a first approximation, not the final definition.
			"peer_veto_rate": peerVetoRate,
			// Process-local draft/AI timings (roadmap B). Reset on restart.
			"draft_requests":         rt.DraftRequests,
			"draft_errors":           rt.DraftErrors,
			"draft_error_rate":       rt.DraftErrorRate,
			"draft_latency_avg_ms":   rt.DraftLatencyAvgMs,
			"draft_latency_max_ms":   rt.DraftLatencyMaxMs,
			"draft_latency_samples":  rt.DraftLatencySamples,
			"escalate_checks":        rt.EscalateChecks,
			"escalate_errors":        rt.EscalateErrors,
			"escalate_error_rate":    rt.EscalateErrorRate,
			"twin_sends_blocked":     rt.TwinSendsBlocked,
			"push_attempts":          rt.PushAttempts,
			"push_skipped":           rt.PushSkipped,
			"push_delivered":         rt.PushDelivered,
			"invites_minted":         invitesMinted,
			"invites_used":   invitesUsed,
		})
	})

	r.POST("/auth/signup", func(c *gin.Context) {
		var req signupRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"detail": err.Error()})
			return
		}

		// 초대 기반 베타(roadmap.md §2.6): 가입은 누군가 실제로 발급한 미사용
		// 코드가 있어야만 된다 -- 아무 문자열이나 처음 쓰면 통과되던 이전
		// 방식은 "초대 기반"이 아니었음.
		var invite InviteCode
		if err := db.Where("code = ?", req.InviteCode).First(&invite).Error; err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"detail": "invalid invite code"})
			return
		}
		if ok, detail := inviteUsable(invite, time.Now()); !ok {
			status := http.StatusBadRequest
			if detail == "invite code already used" {
				status = http.StatusConflict
			}
			c.JSON(status, gin.H{"detail": detail})
			return
		}

		user := User{InviteCode: req.InviteCode, DisplayName: req.DisplayName}
		if err := db.Create(&user).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"detail": err.Error()})
			return
		}
		db.Create(&TwinSettings{UserID: user.ID, AutonomyLevel: AutonomyL0})

		now := time.Now()
		invite.UsedAt = &now
		invite.UsedByUserID = &user.ID
		db.Save(&invite)

		session, err := createSession(db, user.ID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"detail": err.Error()})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"id":           user.ID,
			"display_name": user.DisplayName,
			"token":        session.Token,
			"expires_at":   session.ExpiresAt,
		})
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
		// or erroring) we fail closed and block the send. Peer veto is
		// checked first (it's a total kill switch for this conversation,
		// independent of content), then escalation, then autonomy level --
		// none of the later checks can override an earlier block.
		if req.SenderMode == SenderTwin {
			if conversation.TwinDisabledByPeer {
				runtimeMetrics.recordTwinBlocked()
				c.JSON(http.StatusForbidden, gin.H{"detail": "상대방이 와카뷰를 거부해서 이 대화방에서는 자동 발송이 꺼져 있습니다"})
				return
			}

			result, err := ai.checkEscalation(req.Text)
			runtimeMetrics.recordEscalate(err)
			if err != nil {
				runtimeMetrics.recordTwinBlocked()
				c.JSON(http.StatusBadGateway, gin.H{"detail": "escalation gate unavailable, twin send blocked: " + err.Error()})
				return
			}
			if result.Escalate {
				runtimeMetrics.recordTwinBlocked()
				db.Create(&EscalationLog{
					UserID:         req.SenderID,
					ConversationID: convID,
					Reason:         result.Reason,
					MessageSnippet: req.Text,
				})
				// Best-effort push (no-op without FCM_SERVER_KEY / real tokens).
				_, _, _ = notifyUser(db, req.SenderID, "와카뷰 확인 필요", result.Reason, map[string]string{
					"type":            "escalation",
					"conversation_id": strconv.FormatUint(uint64(convID), 10),
					"reason":          result.Reason,
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
				runtimeMetrics.recordTwinBlocked()
				c.JSON(http.StatusForbidden, gin.H{"detail": "L0(비서 모드)에서는 와카뷰 자동 발송이 허용되지 않습니다 -- 초안만 생성하고 사람이 직접 보내세요"})
				return
			case AutonomyL1:
				if !req.Approved {
					runtimeMetrics.recordTwinBlocked()
					c.JSON(http.StatusForbidden, gin.H{"detail": "L1은 발송 전 사용자 승인이 필요합니다"})
					return
				}
			case AutonomyL2:
				if !req.Approved && !whitelistMatches(db, req.SenderID, convID, req.Text) {
					runtimeMetrics.recordTwinBlocked()
					c.JSON(http.StatusForbidden, gin.H{"detail": "화이트리스트에 없는 주제는 L1과 동일하게 사용자 승인이 필요합니다"})
					return
				}
			default:
				runtimeMetrics.recordTwinBlocked()
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
			"type":        "message",
			"id":          message.ID,
			"sender_id":   message.SenderID,
			"sender_mode": message.SenderMode,
			"text":        message.Text,
		})

		// Return the full message so Flutter can render without waiting on WS.
		c.JSON(http.StatusOK, messageJSON(message))
	})

	r.POST("/messages/:id/retract", func(c *gin.Context) {
		msgID, ok := parseUintParam(c, "id")
		if !ok {
			return
		}

		var message Message
		if err := db.First(&message, msgID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"detail": "message not found"})
			return
		}
		// One-tap undo (PRD.md §3.1, AGENTS.md "every automatic action needs
		// post-hoc notification + one-tap undo") applies to unattended
		// twin auto-sends -- a human retracting their own words is a
		// different, unrelated feature this endpoint doesn't cover.
		if message.SenderMode != SenderTwin {
			c.JSON(http.StatusBadRequest, gin.H{"detail": "only twin-authored (auto-sent) messages can be retracted"})
			return
		}
		if message.Retracted {
			c.JSON(http.StatusConflict, gin.H{"detail": "message already retracted"})
			return
		}

		message.Retracted = true
		if err := db.Save(&message).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"detail": err.Error()})
			return
		}

		relay.broadcast(message.ConversationID, gin.H{
			"type": "retraction",
			"id":   message.ID,
		})

		c.JSON(http.StatusOK, gin.H{"id": message.ID, "retracted": true})
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

		started := time.Now()
		result, err := ai.requestDraft(draftRequest{
			ContextLines:  req.ContextLines,
			StyleExamples: req.StyleExamples,
			History:       req.History,
			K:             req.K,
		})
		runtimeMetrics.recordDraft(time.Since(started), err)
		if err != nil {
			c.JSON(http.StatusBadGateway, gin.H{"detail": err.Error()})
			return
		}

		c.JSON(http.StatusOK, gin.H{"status": result.Status, "text": result.Text})
	})

	r.POST("/conversations/:id/veto", func(c *gin.Context) {
		convID, ok := parseUintParam(c, "id")
		if !ok {
			return
		}

		var conversation Conversation
		if err := db.First(&conversation, convID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"detail": "conversation not found"})
			return
		}

		// Peer veto (PRD.md §3.1, tech-design.md §4, AGENTS.md absolute
		// safety invariants): the counterpart asked to talk to the human
		// only. One-way for v1 -- no "un-veto" endpoint, matching the
		// PRD's "즉시 중단" wording; nothing in scope calls for reversing it.
		conversation.TwinDisabledByPeer = true
		if err := db.Save(&conversation).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"detail": err.Error()})
			return
		}

		c.JSON(http.StatusOK, gin.H{"conversation_id": convID, "twin_disabled_by_peer": true})
	})

	r.PATCH("/users/:id/twin-settings", func(c *gin.Context) {
		userID, ok := parseUintParam(c, "id")
		if !ok {
			return
		}
		if !requireSelf(c, db, userID) {
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

	r.POST("/users/:id/whitelist-rules", func(c *gin.Context) {
		userID, ok := parseUintParam(c, "id")
		if !ok {
			return
		}
		if !requireSelf(c, db, userID) {
			return
		}

		var user User
		if err := db.First(&user, userID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"detail": "user not found"})
			return
		}

		var req createWhitelistRuleRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"detail": err.Error()})
			return
		}

		rule := WhitelistRule{UserID: userID, ContactID: req.ContactID, TopicKeyword: req.TopicKeyword}
		if err := db.Create(&rule).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"detail": err.Error()})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"id":            rule.ID,
			"user_id":       rule.UserID,
			"contact_id":    rule.ContactID,
			"topic_keyword": rule.TopicKeyword,
		})
	})

	r.GET("/users/:id/whitelist-rules", func(c *gin.Context) {
		userID, ok := parseUintParam(c, "id")
		if !ok {
			return
		}
		if !requireSelf(c, db, userID) {
			return
		}

		var user User
		if err := db.First(&user, userID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"detail": "user not found"})
			return
		}

		var rules []WhitelistRule
		db.Where("user_id = ?", userID).Order("id").Find(&rules)

		out := make([]gin.H, 0, len(rules))
		for _, rule := range rules {
			out = append(out, gin.H{
				"id":            rule.ID,
				"contact_id":    rule.ContactID,
				"topic_keyword": rule.TopicKeyword,
			})
		}
		c.JSON(http.StatusOK, gin.H{"whitelist_rules": out})
	})

	r.DELETE("/users/:id/whitelist-rules/:ruleId", func(c *gin.Context) {
		userID, ok := parseUintParam(c, "id")
		if !ok {
			return
		}
		if !requireSelf(c, db, userID) {
			return
		}
		ruleID, ok := parseUintParam(c, "ruleId")
		if !ok {
			return
		}

		var rule WhitelistRule
		if err := db.Where("id = ? AND user_id = ?", ruleID, userID).First(&rule).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"detail": "whitelist rule not found"})
			return
		}
		db.Delete(&rule)

		c.JSON(http.StatusOK, gin.H{"deleted": true})
	})

	r.DELETE("/users/:id", func(c *gin.Context) {
		userID, ok := parseUintParam(c, "id")
		if !ok {
			return
		}
		if !requireSelf(c, db, userID) {
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
			if res := tx.Model(&InviteCode{}).Where("used_by_user_id = ?", userID).Update("used_by_user_id", nil); res.Error != nil {
				return res.Error
			}
			if res := tx.Where("user_id = ?", userID).Delete(&Session{}); res.Error != nil {
				return res.Error
			}
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

// whitelistMatches: keyword substring match, scoped by ContactID when set.
// Rules with ContactID == nil apply to any counterpart. Rules with a
// ContactID apply only when that contact is the peer in this conversation
// (resolved via Contact.ContactUserID ↔ other participant).
func whitelistMatches(db *gorm.DB, userID, conversationID uint, text string) bool {
	var rules []WhitelistRule
	db.Where("user_id = ?", userID).Find(&rules)
	peerContactID := resolvePeerContactID(db, userID, conversationID)
	for _, rule := range rules {
		if !strings.Contains(text, rule.TopicKeyword) {
			continue
		}
		if rule.ContactID == nil {
			return true
		}
		if peerContactID != nil && *rule.ContactID == *peerContactID {
			return true
		}
	}
	return false
}

func generateInviteCode() (string, error) {
	buf := make([]byte, 5)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return hex.EncodeToString(buf), nil
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
	if len(os.Args) > 1 && os.Args[1] == "migrate" {
		_ = openDB()
		return
	}
	db := openDB()
	relay := newConnectionManager()
	ai := newAIServiceClient()
	r := setupRouter(db, relay, ai)
	r.Run(":8080")
}

package main

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// registerGroupSummaryRoutes implements roadmap.md §2.7-A "단톡 따라잡기":
// a read marker per participant + an AI-generated catch-up summary of
// whatever arrived since that marker. Kept separate from a1_a2_routes.go
// since it's new (2026-07-31) scope, not part of the original A1/A2 surface.
func registerGroupSummaryRoutes(r *gin.Engine, db *gorm.DB, ai *AIServiceClient) {
	// POST /conversations/:id/read advances the caller's read marker. Body:
	// {"message_id": <highest message id the client has seen>}. Never moves
	// the marker backward, so out-of-order client calls can't lose history.
	r.POST("/conversations/:id/read", func(c *gin.Context) {
		actor, ok := currentUser(c, db, true)
		if !ok {
			return
		}
		convID, ok := parseUintParam(c, "id")
		if !ok {
			return
		}
		if !isParticipant(db, convID, actor.ID) {
			c.JSON(http.StatusForbidden, gin.H{"detail": "not a participant of this conversation"})
			return
		}
		var req struct {
			MessageID uint `json:"message_id" binding:"required"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"detail": err.Error()})
			return
		}

		var participant ConversationParticipant
		if err := db.Where("conversation_id = ? AND user_id = ?", convID, actor.ID).
			First(&participant).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"detail": "participant record not found"})
			return
		}
		if participant.LastReadMessageID == nil || *participant.LastReadMessageID < req.MessageID {
			participant.LastReadMessageID = &req.MessageID
			if err := db.Save(&participant).Error; err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"detail": err.Error()})
				return
			}
		}
		c.JSON(http.StatusOK, gin.H{"last_read_message_id": participant.LastReadMessageID})
	})

	// GET /conversations/:id/summary returns an AI-generated 3~5 line
	// catch-up of messages since the caller's read marker, focused on
	// mentions of the caller and decisions made (PRD.md §2.3-②). Read-only
	// -- it never sends anything, so it carries none of the escalation/
	// autonomy-level machinery that POST /messages does.
	r.GET("/conversations/:id/summary", func(c *gin.Context) {
		actor, ok := currentUser(c, db, true)
		if !ok {
			return
		}
		convID, ok := parseUintParam(c, "id")
		if !ok {
			return
		}
		if !isParticipant(db, convID, actor.ID) {
			c.JSON(http.StatusForbidden, gin.H{"detail": "not a participant of this conversation"})
			return
		}

		var participant ConversationParticipant
		if err := db.Where("conversation_id = ? AND user_id = ?", convID, actor.ID).
			First(&participant).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"detail": "participant record not found"})
			return
		}

		q := db.Where("conversation_id = ? AND retracted = ?", convID, false)
		if participant.LastReadMessageID != nil {
			q = q.Where("id > ?", *participant.LastReadMessageID)
		}
		var unread []Message
		q.Order("id asc").Find(&unread)

		if len(unread) == 0 {
			c.JSON(http.StatusOK, gin.H{"status": "empty", "summary": "", "unread_count": 0})
			return
		}

		names := map[uint]string{}
		contextLines := make([]string, 0, len(unread))
		needsReply := false
		for _, m := range unread {
			var label string
			if m.SenderID == actor.ID {
				label = "나"
			} else {
				name, cached := names[m.SenderID]
				if !cached {
					var sender User
					if err := db.First(&sender, m.SenderID).Error; err == nil {
						name = sender.DisplayName
					}
					if name == "" {
						name = "상대"
					}
					names[m.SenderID] = name
				}
				label = name
				needsReply = true
			}
			contextLines = append(contextLines, label+": "+m.Text)
		}

		result, err := ai.requestSummary(summaryRequest{
			MyDisplayName: actor.DisplayName,
			ContextLines:  contextLines,
		})
		if err != nil {
			c.JSON(http.StatusBadGateway, gin.H{"detail": err.Error()})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"status":       result.Status,
			"summary":      strings.TrimSpace(result.Summary),
			"unread_count": len(unread),
			"needs_reply":  needsReply,
		})
	})
}

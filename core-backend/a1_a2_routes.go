package main

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type createConversationRequest struct {
	UserIDs   []uint `json:"user_ids" binding:"required"`
	IsGroup   bool   `json:"is_group"`
	ContactID *uint  `json:"contact_id"` // optional: owner's contact for the peer (DM)
}

type createContactRequest struct {
	DisplayName      string `json:"display_name" binding:"required"`
	ContactUserID    *uint  `json:"contact_user_id"`
	RelationshipNote string `json:"relationship_note"`
}

type updateContactRequest struct {
	DisplayName      string `json:"display_name" binding:"required"`
	ContactUserID    *uint  `json:"contact_user_id"`
	RelationshipNote string `json:"relationship_note"`
}

func contactJSON(ct Contact) gin.H {
	return gin.H{
		"id":                ct.ID,
		"display_name":      ct.DisplayName,
		"contact_user_id":   ct.ContactUserID,
		"relationship_note": ct.RelationshipNote,
	}
}

type loginRequest struct {
	InviteCode string `json:"invite_code" binding:"required"`
}

func registerA1A2Routes(r *gin.Engine, db *gorm.DB) {
	r.POST("/auth/login", func(c *gin.Context) {
		var req loginRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"detail": err.Error()})
			return
		}
		var invite InviteCode
		if err := db.Where("code = ?", req.InviteCode).First(&invite).Error; err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"detail": "invalid invite code"})
			return
		}
		if invite.UsedAt == nil || invite.UsedByUserID == nil {
			c.JSON(http.StatusBadRequest, gin.H{"detail": "invite code not yet used for signup"})
			return
		}
		var user User
		if err := db.First(&user, *invite.UsedByUserID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"detail": "user not found"})
			return
		}
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

	r.POST("/conversations", func(c *gin.Context) {
		actor, ok := currentUser(c, db, true)
		if !ok {
			return
		}
		var req createConversationRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"detail": err.Error()})
			return
		}
		if len(req.UserIDs) < 1 {
			c.JSON(http.StatusBadRequest, gin.H{"detail": "user_ids must include at least one participant"})
			return
		}
		// Creator must be a participant.
		includesSelf := false
		for _, id := range req.UserIDs {
			if id == actor.ID {
				includesSelf = true
				break
			}
		}
		if !includesSelf {
			req.UserIDs = append(req.UserIDs, actor.ID)
		}

		if req.ContactID != nil {
			var contact Contact
			if err := db.Where("id = ? AND owner_user_id = ?", *req.ContactID, actor.ID).First(&contact).Error; err != nil {
				c.JSON(http.StatusBadRequest, gin.H{"detail": "contact_id must belong to the authenticated user"})
				return
			}
		}

		var conv Conversation
		err := db.Transaction(func(tx *gorm.DB) error {
			conv = Conversation{IsGroup: req.IsGroup}
			if err := tx.Create(&conv).Error; err != nil {
				return err
			}
			seen := map[uint]bool{}
			for _, uid := range req.UserIDs {
				if seen[uid] {
					continue
				}
				seen[uid] = true
				var user User
				if err := tx.First(&user, uid).Error; err != nil {
					return err
				}
				if err := tx.Create(&ConversationParticipant{ConversationID: conv.ID, UserID: uid}).Error; err != nil {
					return err
				}
			}
			// Link owner's contact → conversation via RelationshipNote field? No —
			// store on Contact by setting ContactUserID already; for whitelist we
			// resolve peer via participants. Optionally stamp contact's linked user.
			if req.ContactID != nil {
				// Ensure contact points at the other participant when possible.
				var contact Contact
				if err := tx.First(&contact, *req.ContactID).Error; err != nil {
					return err
				}
				for _, uid := range req.UserIDs {
					if uid != actor.ID {
						contact.ContactUserID = &uid
						if err := tx.Save(&contact).Error; err != nil {
							return err
						}
						break
					}
				}
			}
			return nil
		})
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"detail": err.Error()})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"id":       conv.ID,
			"is_group": conv.IsGroup,
			"user_ids": req.UserIDs,
		})
	})

	r.GET("/conversations", func(c *gin.Context) {
		actor, ok := currentUser(c, db, true)
		if !ok {
			return
		}
		userID := actor.ID
		if q := c.Query("user_id"); q != "" {
			parsed, err := strconv.ParseUint(q, 10, 64)
			if err != nil {
				c.JSON(http.StatusBadRequest, gin.H{"detail": "user_id must be a positive integer"})
				return
			}
			if uint(parsed) != actor.ID {
				c.JSON(http.StatusForbidden, gin.H{"detail": "can only list your own conversations"})
				return
			}
			userID = uint(parsed)
		}

		var parts []ConversationParticipant
		db.Where("user_id = ?", userID).Find(&parts)
		out := make([]gin.H, 0, len(parts))
		for _, p := range parts {
			var conv Conversation
			if err := db.First(&conv, p.ConversationID).Error; err != nil {
				continue
			}
			var participantIDs []uint
			var pps []ConversationParticipant
			db.Where("conversation_id = ?", conv.ID).Find(&pps)
			for _, pp := range pps {
				participantIDs = append(participantIDs, pp.UserID)
			}
			out = append(out, gin.H{
				"id":                    conv.ID,
				"is_group":              conv.IsGroup,
				"twin_disabled_by_peer": conv.TwinDisabledByPeer,
				"user_ids":              participantIDs,
				"created_at":            conv.CreatedAt,
			})
		}
		c.JSON(http.StatusOK, gin.H{"conversations": out})
	})

	r.GET("/conversations/:id/messages", func(c *gin.Context) {
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
		var messages []Message
		db.Where("conversation_id = ?", convID).Order("id asc").Find(&messages)
		out := make([]gin.H, 0, len(messages))
		for _, m := range messages {
			out = append(out, gin.H{
				"id":              m.ID,
				"conversation_id": m.ConversationID,
				"sender_id":       m.SenderID,
				"sender_mode":     m.SenderMode,
				"text":            m.Text,
				"retracted":       m.Retracted,
				"created_at":      m.CreatedAt,
			})
		}
		c.JSON(http.StatusOK, gin.H{"messages": out})
	})

	r.POST("/users/:id/contacts", func(c *gin.Context) {
		userID, ok := parseUintParam(c, "id")
		if !ok {
			return
		}
		if !requireSelf(c, db, userID) {
			return
		}
		var req createContactRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"detail": err.Error()})
			return
		}
		contact := Contact{
			OwnerUserID:      userID,
			ContactUserID:    req.ContactUserID,
			DisplayName:      req.DisplayName,
			RelationshipNote: req.RelationshipNote,
		}
		if err := db.Create(&contact).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"detail": err.Error()})
			return
		}
		c.JSON(http.StatusOK, contactJSON(contact))
	})

	r.GET("/users/:id/contacts", func(c *gin.Context) {
		userID, ok := parseUintParam(c, "id")
		if !ok {
			return
		}
		if !requireSelf(c, db, userID) {
			return
		}
		var contacts []Contact
		db.Where("owner_user_id = ?", userID).Order("id").Find(&contacts)
		out := make([]gin.H, 0, len(contacts))
		for _, ct := range contacts {
			out = append(out, contactJSON(ct))
		}
		c.JSON(http.StatusOK, gin.H{"contacts": out})
	})

	r.PATCH("/users/:id/contacts/:contactId", func(c *gin.Context) {
		userID, ok := parseUintParam(c, "id")
		if !ok {
			return
		}
		if !requireSelf(c, db, userID) {
			return
		}
		contactID, ok := parseUintParam(c, "contactId")
		if !ok {
			return
		}
		var req updateContactRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"detail": err.Error()})
			return
		}
		var contact Contact
		if err := db.Where("id = ? AND owner_user_id = ?", contactID, userID).First(&contact).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"detail": "contact not found"})
			return
		}
		if req.ContactUserID != nil && *req.ContactUserID == userID {
			c.JSON(http.StatusBadRequest, gin.H{"detail": "cannot set contact_user_id to yourself"})
			return
		}
		contact.DisplayName = req.DisplayName
		contact.ContactUserID = req.ContactUserID
		contact.RelationshipNote = req.RelationshipNote
		if err := db.Save(&contact).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"detail": err.Error()})
			return
		}
		c.JSON(http.StatusOK, contactJSON(contact))
	})

	r.DELETE("/users/:id/contacts/:contactId", func(c *gin.Context) {
		userID, ok := parseUintParam(c, "id")
		if !ok {
			return
		}
		if !requireSelf(c, db, userID) {
			return
		}
		contactID, ok := parseUintParam(c, "contactId")
		if !ok {
			return
		}
		var contact Contact
		if err := db.Where("id = ? AND owner_user_id = ?", contactID, userID).First(&contact).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"detail": "contact not found"})
			return
		}
		db.Delete(&contact)
		c.JSON(http.StatusOK, gin.H{"deleted": true})
	})

	r.GET("/users/:id/escalation-logs", func(c *gin.Context) {
		userID, ok := parseUintParam(c, "id")
		if !ok {
			return
		}
		if !requireSelf(c, db, userID) {
			return
		}
		var logs []EscalationLog
		db.Where("user_id = ?", userID).Order("id desc").Find(&logs)
		out := make([]gin.H, 0, len(logs))
		for _, l := range logs {
			out = append(out, gin.H{
				"id":              l.ID,
				"conversation_id": l.ConversationID,
				"reason":          l.Reason,
				"message_snippet": l.MessageSnippet,
				"resolved":        l.Resolved,
				"created_at":      l.CreatedAt,
			})
		}
		c.JSON(http.StatusOK, gin.H{"escalation_logs": out})
	})
}

func isParticipant(db *gorm.DB, conversationID, userID uint) bool {
	var n int64
	db.Model(&ConversationParticipant{}).
		Where("conversation_id = ? AND user_id = ?", conversationID, userID).
		Count(&n)
	return n > 0
}

// resolvePeerContactID finds the owner's Contact row for the other party in
// a conversation (Contact.ContactUserID == other participant).
func resolvePeerContactID(db *gorm.DB, ownerUserID, conversationID uint) *uint {
	var parts []ConversationParticipant
	db.Where("conversation_id = ?", conversationID).Find(&parts)
	for _, p := range parts {
		if p.UserID == ownerUserID {
			continue
		}
		var contact Contact
		if err := db.Where("owner_user_id = ? AND contact_user_id = ?", ownerUserID, p.UserID).First(&contact).Error; err == nil {
			id := contact.ID
			return &id
		}
	}
	return nil
}

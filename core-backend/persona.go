package main

import "gorm.io/gorm"

// resolveRelationshipTier implements roadmap.md §2.7-B: draft tone should
// read differently for a close friend than for someone you'd stay formal
// with. Resolution order: contact-specific override (1:1 only) -> the
// sender's global TwinSettings default -> "formal" as the fail-safe
// fallback if nothing is set. Group conversations always use the global
// default since a group has more than one counterpart to pick a tier for.
func resolveRelationshipTier(db *gorm.DB, actorID, conversationID uint) RelationshipTier {
	var conv Conversation
	if err := db.First(&conv, conversationID).Error; err == nil && !conv.IsGroup {
		var parts []ConversationParticipant
		db.Where("conversation_id = ?", conversationID).Find(&parts)
		for _, p := range parts {
			if p.UserID == actorID {
				continue
			}
			var contact Contact
			err := db.Where("owner_user_id = ? AND contact_user_id = ?", actorID, p.UserID).First(&contact).Error
			if err == nil && contact.RelationshipTier != nil && validRelationshipTier(*contact.RelationshipTier) {
				return *contact.RelationshipTier
			}
			break
		}
	}

	var settings TwinSettings
	if err := db.Where("user_id = ?", actorID).First(&settings).Error; err == nil && validRelationshipTier(settings.RelationshipTier) {
		return settings.RelationshipTier
	}
	return RelationshipFormal
}

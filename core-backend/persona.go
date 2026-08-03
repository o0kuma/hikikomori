package main

import "gorm.io/gorm"

// findCounterpartContact locates the Contact row (if any) representing the
// other person in a 1:1 conversation, from actorID's point of view. Shared
// by resolveRelationshipTier (§2.7-B), resolveAutonomyLevel (§2.7-D), and
// resolveRelationshipNote (§2.7-E) -- all three need the exact same
// "which Contact row applies to this actor+conversation" lookup and only
// differ in which field of the result they read. Returns ok=false for group
// conversations (more than one counterpart, so no single contact applies)
// or when no Contact row exists between actorID and the other participant.
func findCounterpartContact(db *gorm.DB, actorID, conversationID uint) (Contact, bool) {
	var conv Conversation
	if err := db.First(&conv, conversationID).Error; err != nil || conv.IsGroup {
		return Contact{}, false
	}
	var parts []ConversationParticipant
	db.Where("conversation_id = ?", conversationID).Find(&parts)
	for _, p := range parts {
		if p.UserID == actorID {
			continue
		}
		var contact Contact
		if err := db.Where("owner_user_id = ? AND contact_user_id = ?", actorID, p.UserID).First(&contact).Error; err == nil {
			return contact, true
		}
		break
	}
	return Contact{}, false
}

// resolveRelationshipTier implements roadmap.md §2.7-B: draft tone should
// read differently for a close friend than for someone you'd stay formal
// with. Resolution order: contact-specific override (1:1 only) -> the
// sender's global TwinSettings default -> "formal" as the fail-safe
// fallback if nothing is set. Group conversations always use the global
// default since a group has more than one counterpart to pick a tier for.
func resolveRelationshipTier(db *gorm.DB, actorID, conversationID uint) RelationshipTier {
	if contact, ok := findCounterpartContact(db, actorID, conversationID); ok {
		if contact.RelationshipTier != nil && validRelationshipTier(*contact.RelationshipTier) {
			return *contact.RelationshipTier
		}
	}

	var settings TwinSettings
	if err := db.Where("user_id = ?", actorID).First(&settings).Error; err == nil && validRelationshipTier(settings.RelationshipTier) {
		return settings.RelationshipTier
	}
	return RelationshipFormal
}

// resolveRelationshipNote implements roadmap.md §2.7-E: Contact.RelationshipNote
// (a free-text note like "호칭: 자기야, 절대 언급 금지: 전 여친") already has full
// CRUD but never reached the draft prompt -- this makes it actually flow into
// ai-service. Unlike relationship tier / autonomy level, a note is inherently
// per-person: there is no "global default note" to fall back to. So this
// simply returns "" for group conversations, for a 1:1 with no matching
// Contact row, or for a Contact whose note is unset -- ai-service treats an
// empty note as "no extra instruction", identical to today's behavior.
func resolveRelationshipNote(db *gorm.DB, actorID, conversationID uint) string {
	if contact, ok := findCounterpartContact(db, actorID, conversationID); ok {
		return contact.RelationshipNote
	}
	return ""
}

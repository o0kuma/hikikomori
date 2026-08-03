package main

import "gorm.io/gorm"

// resolveAutonomyLevel implements roadmap.md §2.7-D: a user may want L2
// (auto-send) with a close friend but L0 (drafts only) with someone else --
// PRD.md §3.1 "자율성 설정(L0~L2) | 전역 기본값 + 상대별 예외 설정" and §4
// "사용자가 여러 상대에게 다른 자율성 레벨을 원함". Mirrors
// resolveRelationshipTier's structure exactly (both share persona.go's
// findCounterpartContact lookup). Resolution order: contact-specific
// override (1:1 only) -> the sender's global TwinSettings default ->
// AutonomyL0 as the fail-safe fallback if nothing is set (L0 is the
// documented safe default everywhere else in this codebase -- never fail
// open to L1/L2). Group conversations always use the global default, same
// as relationship tier, since a group has more than one counterpart to pick
// a level for -- note this resolver only decides the L0/L1/L2 branch; the
// unconditional "group conversations never auto-send" hard block in
// main.go's POST /conversations/:id/messages runs earlier and independent
// of this function's result.
func resolveAutonomyLevel(db *gorm.DB, actorID, conversationID uint) AutonomyLevel {
	if contact, ok := findCounterpartContact(db, actorID, conversationID); ok {
		if contact.AutonomyLevel != nil && validAutonomyLevel(*contact.AutonomyLevel) {
			return *contact.AutonomyLevel
		}
	}

	var settings TwinSettings
	if err := db.Where("user_id = ?", actorID).First(&settings).Error; err == nil && validAutonomyLevel(settings.AutonomyLevel) {
		return settings.AutonomyLevel
	}
	return AutonomyL0
}

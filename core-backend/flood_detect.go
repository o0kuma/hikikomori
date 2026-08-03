package main

import (
	"fmt"
	"time"

	"gorm.io/gorm"
)

// Flood/spam detection minimum version (roadmap.md §2.7-C, PRD.md §4
// 엣지케이스: "상대가 짧은 시간에 메시지 도배 -> 스팸 감지 임계치 초과 시 응대
// 중단, 사용자에게 보고 (P1이지만 안전 관련이라 v1 최소 버전 필요)").
//
// These two constants are a conservative, clearly-labeled v1-minimum
// placeholder, NOT a PoC-validated number -- unlike the autonomy-default/
// whitelist-default questions in roadmap.md §3 ("PoC 결과가 있어야 정할 수
// 있는 것"), this is a technical safety minimum that has to exist for P0
// coverage, so it's fine to ship a placeholder and revisit with real usage
// data later rather than leaving the gate unbuilt.
const (
	// floodMessageThreshold is how many incoming messages from the
	// counterpart within floodWindow count as "도배".
	floodMessageThreshold = 5
	// floodWindow is the trailing window floodMessageThreshold is counted over.
	floodWindow = 2 * time.Minute
)

// floodIncomingCount counts messages in conversationID sent by anyone other
// than ownerUserID (i.e. the counterpart's own words, not the twin's
// auto-sends nor the owner's own human-typed messages, both of which use
// SenderID == ownerUserID -- see sendMessageRequest.SenderID) within the
// trailing floodWindow. Retracted messages still count: retraction undoes an
// auto-send the twin/owner made, it says nothing about whether the peer was
// flooding.
func floodIncomingCount(db *gorm.DB, conversationID, ownerUserID uint) int64 {
	var count int64
	db.Model(&Message{}).
		Where("conversation_id = ? AND sender_id != ? AND created_at >= ?",
			conversationID, ownerUserID, time.Now().Add(-floodWindow)).
		Count(&count)
	return count
}

// floodDetected reports whether the counterpart has crossed
// floodMessageThreshold within floodWindow for this conversation, plus the
// count for the resulting EscalationLog reason string.
func floodDetected(db *gorm.DB, conversationID, ownerUserID uint) (bool, int64) {
	count := floodIncomingCount(db, conversationID, ownerUserID)
	return count > floodMessageThreshold, count
}

// floodReason formats the Korean EscalationLog copy for a flood auto-pause,
// matching the tone of the existing escalation_filter reasons.
func floodReason(count int64) string {
	return fmt.Sprintf("도배 감지: 최근 %d분 동안 상대로부터 메시지 %d건 수신 (임계치 %d건) -- 자동응대 일시중단",
		int(floodWindow/time.Minute), count, floodMessageThreshold)
}

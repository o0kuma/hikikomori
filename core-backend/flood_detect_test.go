package main

import (
	"net/http"
	"strconv"
	"testing"
	"time"

	"gorm.io/gorm"
)

// seedIncomingMessages inserts n messages from a counterpart (any sender_id
// != ownerID) into conv, timestamped now, simulating a peer flooding the
// conversation. Uses db.Create directly (like the peer-veto tests above)
// rather than going through POST /messages, since that endpoint's gating
// only applies to sender_mode=twin and these are meant to be plain incoming
// human messages from the other party.
func seedIncomingMessages(t *testing.T, db *gorm.DB, conv Conversation, ownerID uint, n int) {
	t.Helper()
	peerID := ownerID + 1000 // any id distinct from the owner
	for i := 0; i < n; i++ {
		db.Create(&Message{
			ConversationID: conv.ID,
			SenderID:       peerID,
			SenderMode:     SenderHuman,
			Text:           "spam " + strconv.Itoa(i),
		})
	}
}

func TestFloodDetectionBlocksTwinAutoSendAfterThresholdExceeded(t *testing.T) {
	server, db := setupTestServer(t)

	senderID, token := mustSignup(t, server.URL, "도배테스트")
	setAutonomyLevel(t, server.URL, senderID, token, AutonomyL2)
	db.Create(&WhitelistRule{UserID: senderID, TopicKeyword: "ㅇㅇ"})

	conv := Conversation{IsGroup: false}
	if err := db.Create(&conv).Error; err != nil {
		t.Fatalf("create conversation: %v", err)
	}
	convBase := server.URL + "/conversations/" + strconv.FormatUint(uint64(conv.ID), 10)

	// Below threshold: the counterpart sending floodMessageThreshold messages
	// exactly must NOT trip the gate yet (strictly greater-than semantics).
	seedIncomingMessages(t, db, conv, senderID, floodMessageThreshold)
	resp := postJSON(t, convBase+"/messages", sendMessageRequest{
		SenderID: senderID, Text: "ㅇㅇ 알겠어", SenderMode: SenderTwin, Approved: true,
	})
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 at exactly the threshold (not yet exceeded), got %d", resp.StatusCode)
	}

	// One more incoming message tips it over the threshold.
	seedIncomingMessages(t, db, conv, senderID, 1)
	blocked := postJSON(t, convBase+"/messages", sendMessageRequest{
		SenderID: senderID, Text: "ㅇㅇ 또 왔어", SenderMode: SenderTwin, Approved: true,
	})
	if blocked.StatusCode != http.StatusForbidden {
		t.Fatalf("expected 403 once flood threshold is exceeded, got %d", blocked.StatusCode)
	}

	var conv2 Conversation
	if err := db.First(&conv2, conv.ID).Error; err != nil {
		t.Fatalf("reload conversation: %v", err)
	}
	if !conv2.TwinDisabledByFlood {
		t.Fatal("expected twin_disabled_by_flood to be set after flood detection")
	}

	var logs []EscalationLog
	db.Where("conversation_id = ?", conv.ID).Find(&logs)
	if len(logs) != 1 {
		t.Fatalf("expected exactly one EscalationLog row for the flood block, got %d", len(logs))
	}

	// The gate must stay closed on a subsequent attempt without re-counting
	// (also prevents duplicate EscalationLog rows piling up per attempt).
	again := postJSON(t, convBase+"/messages", sendMessageRequest{
		SenderID: senderID, Text: "ㅇㅇ 세번째", SenderMode: SenderTwin, Approved: true,
	})
	if again.StatusCode != http.StatusForbidden {
		t.Fatalf("expected 403 to persist once flood-blocked, got %d", again.StatusCode)
	}
	db.Where("conversation_id = ?", conv.ID).Find(&logs)
	if len(logs) != 1 {
		t.Fatalf("expected the flood EscalationLog to stay at 1 row, got %d", len(logs))
	}
}

func TestFloodDetectionDoesNotBlockHumanMessages(t *testing.T) {
	server, db := setupTestServer(t)

	senderID, _ := mustSignup(t, server.URL, "도배사람")
	conv := Conversation{IsGroup: false}
	if err := db.Create(&conv).Error; err != nil {
		t.Fatalf("create conversation: %v", err)
	}
	convBase := server.URL + "/conversations/" + strconv.FormatUint(uint64(conv.ID), 10)

	seedIncomingMessages(t, db, conv, senderID, floodMessageThreshold+5)

	// The owner's own human-authored message is never gated, flood or
	// otherwise -- it's their own words.
	resp := postJSON(t, convBase+"/messages", sendMessageRequest{
		SenderID: senderID, Text: "괜찮아?", SenderMode: SenderHuman,
	})
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("flood detection must not block human-authored messages, got %d", resp.StatusCode)
	}
}

func TestFloodDetectionOnlyCountsMessagesWithinWindow(t *testing.T) {
	server, db := setupTestServer(t)

	senderID, token := mustSignup(t, server.URL, "옛도배")
	setAutonomyLevel(t, server.URL, senderID, token, AutonomyL1)

	conv := Conversation{IsGroup: false}
	if err := db.Create(&conv).Error; err != nil {
		t.Fatalf("create conversation: %v", err)
	}
	convBase := server.URL + "/conversations/" + strconv.FormatUint(uint64(conv.ID), 10)

	// Stale messages from outside floodWindow must not count toward the
	// threshold, even though there are plenty of them.
	peerID := senderID + 1000
	stale := time.Now().Add(-floodWindow * 3)
	for i := 0; i < floodMessageThreshold+10; i++ {
		db.Create(&Message{
			ConversationID: conv.ID,
			SenderID:       peerID,
			SenderMode:     SenderHuman,
			Text:           "old spam",
			CreatedAt:      stale,
		})
	}

	resp := postJSON(t, convBase+"/messages", sendMessageRequest{
		SenderID: senderID, Text: "ㅇㅇ 알겠어", SenderMode: SenderTwin, Approved: true,
	})
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("stale messages outside floodWindow must not trigger the gate, got %d", resp.StatusCode)
	}
}

func TestFloodResetReenablesTwinAutoSend(t *testing.T) {
	server, db := setupTestServer(t)

	senderID, token := mustSignup(t, server.URL, "재개테스트")
	setAutonomyLevel(t, server.URL, senderID, token, AutonomyL1)

	conv := Conversation{IsGroup: false}
	if err := db.Create(&conv).Error; err != nil {
		t.Fatalf("create conversation: %v", err)
	}
	convBase := server.URL + "/conversations/" + strconv.FormatUint(uint64(conv.ID), 10)

	seedIncomingMessages(t, db, conv, senderID, floodMessageThreshold+1)
	blocked := postJSON(t, convBase+"/messages", sendMessageRequest{
		SenderID: senderID, Text: "ㅇㅇ", SenderMode: SenderTwin, Approved: true,
	})
	if blocked.StatusCode != http.StatusForbidden {
		t.Fatalf("expected 403 once flooded, got %d", blocked.StatusCode)
	}

	// One-tap undo (AGENTS.md "every automatic action needs post-hoc
	// notification + one-tap undo") -- unlike peer veto, this auto-pause
	// must be reversible.
	resetResp := postJSON(t, convBase+"/flood-reset", nil)
	if resetResp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 resetting flood block, got %d", resetResp.StatusCode)
	}

	var conv2 Conversation
	if err := db.First(&conv2, conv.ID).Error; err != nil {
		t.Fatalf("reload conversation: %v", err)
	}
	if conv2.TwinDisabledByFlood {
		t.Fatal("expected twin_disabled_by_flood to be cleared after flood-reset")
	}

	// The flood messages that tripped the gate are still inside floodWindow
	// right after reset, so without clearing them a resend would immediately
	// re-trip the same detection (correct fail-safe behavior, but not what
	// this test is checking) -- simulate the message rate having actually
	// dropped, which is the case flood-reset is meant for.
	db.Where("conversation_id = ?", conv.ID).Delete(&Message{})

	resent := postJSON(t, convBase+"/messages", sendMessageRequest{
		SenderID: senderID, Text: "ㅇㅇ 다시", SenderMode: SenderTwin, Approved: true,
	})
	if resent.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 after flood-reset re-enabled auto-send, got %d", resent.StatusCode)
	}
}

func TestFloodResetMissingConversation(t *testing.T) {
	server, _ := setupTestServer(t)
	resp := postJSON(t, server.URL+"/conversations/9999/flood-reset", nil)
	if resp.StatusCode != http.StatusNotFound {
		t.Fatalf("expected 404, got %d", resp.StatusCode)
	}
}

package main

import (
	"encoding/json"
	"net/http"
	"strconv"
	"testing"
)

// TestContactAutonomyLevelOverridesGlobalDefaultInSendGate mirrors
// TestContactRelationshipTierOverridesGlobalDefaultInDraft: global default
// stays at the signup default (L0, which blocks all twin auto-send), but a
// per-contact override raises it to L2 for this specific counterpart, so a
// whitelisted twin message goes through without requiring approval.
func TestContactAutonomyLevelOverridesGlobalDefaultInSendGate(t *testing.T) {
	server, db := setupTestServer(t)
	ownerID, ownerToken := mustSignup(t, server.URL, "민수")
	peerID, _ := mustSignup(t, server.URL, "철수")

	l2 := AutonomyL2
	contactResp := postJSONAuth(t, server.URL+"/users/"+strconv.FormatUint(uint64(ownerID), 10)+"/contacts", ownerToken, createContactRequest{
		DisplayName:   "철수",
		ContactUserID: &peerID,
		AutonomyLevel: &l2,
	})
	if contactResp.StatusCode != http.StatusOK {
		t.Fatalf("create contact: %d", contactResp.StatusCode)
	}

	db.Create(&WhitelistRule{UserID: ownerID, TopicKeyword: "ㅇㅇ"})

	convResp := postJSONAuth(t, server.URL+"/conversations", ownerToken, createConversationRequest{
		UserIDs: []uint{ownerID, peerID},
	})
	var conv map[string]interface{}
	json.NewDecoder(convResp.Body).Decode(&conv)
	convID := uint(conv["id"].(float64))

	// Global default is still L0 (never changed) -- without the contact
	// override this would 403. Approved is false and Text matches the
	// whitelist keyword, which only clears the gate at L2.
	resp := postJSON(t, server.URL+"/conversations/"+strconv.FormatUint(uint64(convID), 10)+"/messages", sendMessageRequest{
		SenderID: ownerID, Text: "ㅇㅇ 알겠어", SenderMode: SenderTwin,
	})
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 (contact override L2 + whitelist match), got %d", resp.StatusCode)
	}
}

// TestSendGateFallsBackToGlobalAutonomyWithoutContactOverride mirrors
// TestDraftFallsBackToGlobalTierWithoutContactOverride: no contact record at
// all -- resolveAutonomyLevel must fall back to the sender's global
// TwinSettings.AutonomyLevel rather than erroring or defaulting to L0 when a
// non-L0 global level was explicitly set.
func TestSendGateFallsBackToGlobalAutonomyWithoutContactOverride(t *testing.T) {
	server, _ := setupTestServer(t)
	ownerID, ownerToken := mustSignup(t, server.URL, "민수")
	peerID, _ := mustSignup(t, server.URL, "철수")
	setAutonomyLevel(t, server.URL, ownerID, ownerToken, AutonomyL1)

	convResp := postJSONAuth(t, server.URL+"/conversations", ownerToken, createConversationRequest{
		UserIDs: []uint{ownerID, peerID},
	})
	var conv map[string]interface{}
	json.NewDecoder(convResp.Body).Decode(&conv)
	convID := uint(conv["id"].(float64))

	// L1 without approval must still block.
	blocked := postJSON(t, server.URL+"/conversations/"+strconv.FormatUint(uint64(convID), 10)+"/messages", sendMessageRequest{
		SenderID: ownerID, Text: "안녕하세요", SenderMode: SenderTwin,
	})
	if blocked.StatusCode != http.StatusForbidden {
		t.Fatalf("expected 403 for unapproved L1 send, got %d", blocked.StatusCode)
	}

	// L1 with approval must go through -- confirms the global default (not
	// some stray L0 fallback) is really what got resolved.
	approved := postJSON(t, server.URL+"/conversations/"+strconv.FormatUint(uint64(convID), 10)+"/messages", sendMessageRequest{
		SenderID: ownerID, Text: "안녕하세요", SenderMode: SenderTwin, Approved: true,
	})
	if approved.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 for approved L1 send using global default, got %d", approved.StatusCode)
	}
}

// TestGroupConversationAutonomyAlwaysUsesGlobalDefaultNotContactOverride
// verifies resolveAutonomyLevel's own group-conversation branch directly
// (the unconditional "no twin auto-send in groups" hard block in main.go
// already stops group sends earlier and independently -- this test is about
// resolveAutonomyLevel's resolution order, mirroring
// TestGroupConversationDraftUsesGlobalTierNotContactOverride).
func TestGroupConversationAutonomyAlwaysUsesGlobalDefaultNotContactOverride(t *testing.T) {
	server, db := setupTestServer(t)
	ownerID, ownerToken := mustSignup(t, server.URL, "민수")
	peerID, _ := mustSignup(t, server.URL, "철수")

	l2 := AutonomyL2
	postJSONAuth(t, server.URL+"/users/"+strconv.FormatUint(uint64(ownerID), 10)+"/contacts", ownerToken, createContactRequest{
		DisplayName:   "철수",
		ContactUserID: &peerID,
		AutonomyLevel: &l2,
	})

	convID := createGroup(t, server.URL, ownerToken, []uint{ownerID, peerID})

	// Global default is still the signup default (L0). Even though the
	// contact has an L2 override, a group conversation must never pick it up.
	got := resolveAutonomyLevel(db, ownerID, convID)
	if got != AutonomyL0 {
		t.Fatalf("expected group conversation to resolve global default L0 ignoring contact override, got %v", got)
	}
}

// TestDraftGroupConversationHardBlockStillWinsOverAutonomyLevel is a smoke
// check that the pre-existing "no twin auto-send in groups" hard block
// (roadmap.md §2.7-A) still runs before -- and independent of -- the
// autonomy gate, even when a contact override would otherwise allow L2.
func TestGroupConversationSendStillBlockedRegardlessOfContactAutonomyOverride(t *testing.T) {
	server, _ := setupTestServer(t)
	ownerID, ownerToken := mustSignup(t, server.URL, "민수")
	peerID, _ := mustSignup(t, server.URL, "철수")

	l2 := AutonomyL2
	postJSONAuth(t, server.URL+"/users/"+strconv.FormatUint(uint64(ownerID), 10)+"/contacts", ownerToken, createContactRequest{
		DisplayName:   "철수",
		ContactUserID: &peerID,
		AutonomyLevel: &l2,
	})

	convID := createGroup(t, server.URL, ownerToken, []uint{ownerID, peerID})

	resp := postJSON(t, server.URL+"/conversations/"+strconv.FormatUint(uint64(convID), 10)+"/messages", sendMessageRequest{
		SenderID: ownerID, Text: "그룹에서 자동발송 시도", SenderMode: SenderTwin, Approved: true,
	})
	if resp.StatusCode != http.StatusForbidden {
		t.Fatalf("expected 403 for group twin auto-send regardless of contact autonomy override, got %d", resp.StatusCode)
	}
}

func TestResolveAutonomyLevelFallsBackToL0WithNoSettingsAtAll(t *testing.T) {
	server, db := setupTestServer(t)
	// A conversation with a sender that never signed up / has no
	// TwinSettings row at all must fail closed to L0, not error out.
	conv := Conversation{IsGroup: false}
	if err := db.Create(&conv).Error; err != nil {
		t.Fatalf("create conversation: %v", err)
	}
	_ = server

	got := resolveAutonomyLevel(db, 999999, conv.ID)
	if got != AutonomyL0 {
		t.Fatalf("expected fail-safe default L0 for unknown user, got %v", got)
	}
}

func TestCreateContactRejectsInvalidAutonomyLevel(t *testing.T) {
	server, _ := setupTestServer(t)
	ownerID, ownerToken := mustSignup(t, server.URL, "민수")

	bad := AutonomyLevel("L9")
	resp := postJSONAuth(t, server.URL+"/users/"+strconv.FormatUint(uint64(ownerID), 10)+"/contacts", ownerToken, createContactRequest{
		DisplayName:   "이상함",
		AutonomyLevel: &bad,
	})
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("expected 400 creating contact with invalid autonomy_level, got %d", resp.StatusCode)
	}
}

func TestUpdateContactRejectsInvalidAutonomyLevel(t *testing.T) {
	server, _ := setupTestServer(t)
	ownerID, ownerToken := mustSignup(t, server.URL, "민수")

	createResp := postJSONAuth(t, server.URL+"/users/"+strconv.FormatUint(uint64(ownerID), 10)+"/contacts", ownerToken, createContactRequest{
		DisplayName: "친구",
	})
	var created map[string]interface{}
	json.NewDecoder(createResp.Body).Decode(&created)
	contactID := uint(created["id"].(float64))

	bad := AutonomyLevel("nope")
	resp := patchJSONAuth(t, server.URL+"/users/"+strconv.FormatUint(uint64(ownerID), 10)+"/contacts/"+strconv.FormatUint(uint64(contactID), 10), ownerToken, updateContactRequest{
		DisplayName:   "친구",
		AutonomyLevel: &bad,
	})
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("expected 400 updating contact with invalid autonomy_level, got %d", resp.StatusCode)
	}
}

// TestUpdateContactFullReplaceResetsAutonomyLevelOverride confirms Contact
// PATCH is full-replace (like every other Contact field, unlike TwinSettings
// PATCH which is conditional/partial) -- omitting autonomy_level on a later
// PATCH resets the override back to nil (use the global default), it does
// not leave the previous override in place.
func TestUpdateContactFullReplaceResetsAutonomyLevelOverride(t *testing.T) {
	server, _ := setupTestServer(t)
	ownerID, ownerToken := mustSignup(t, server.URL, "민수")
	peerID, _ := mustSignup(t, server.URL, "철수")

	l2 := AutonomyL2
	createResp := postJSONAuth(t, server.URL+"/users/"+strconv.FormatUint(uint64(ownerID), 10)+"/contacts", ownerToken, createContactRequest{
		DisplayName:   "철수",
		ContactUserID: &peerID,
		AutonomyLevel: &l2,
	})
	var created map[string]interface{}
	json.NewDecoder(createResp.Body).Decode(&created)
	contactID := uint(created["id"].(float64))
	if created["autonomy_level"] != "L2" {
		t.Fatalf("expected autonomy_level L2 right after create, got %v", created["autonomy_level"])
	}

	// Update without autonomy_level in the request body -- full-replace
	// semantics mean this must reset it to nil, exactly like
	// relationship_tier does today.
	updateResp := patchJSONAuth(t, server.URL+"/users/"+strconv.FormatUint(uint64(ownerID), 10)+"/contacts/"+strconv.FormatUint(uint64(contactID), 10), ownerToken, updateContactRequest{
		DisplayName:   "철수",
		ContactUserID: &peerID,
	})
	if updateResp.StatusCode != http.StatusOK {
		t.Fatalf("update contact: %d", updateResp.StatusCode)
	}
	var updated map[string]interface{}
	json.NewDecoder(updateResp.Body).Decode(&updated)
	if updated["autonomy_level"] != nil {
		t.Fatalf("expected autonomy_level to reset to nil after omitting it on PATCH, got %v", updated["autonomy_level"])
	}
}

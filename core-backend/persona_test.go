package main

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"
	"testing"
)

func TestPatchTwinSettingsUpdatesRelationshipTier(t *testing.T) {
	server, _ := setupTestServer(t)
	userID, token := mustSignup(t, server.URL, "민수")

	tier := RelationshipClose
	resp := patchJSONAuth(t, server.URL+"/users/"+strconv.FormatUint(uint64(userID), 10)+"/twin-settings", token, updateTwinSettingsRequest{
		AutonomyLevel:    AutonomyL1,
		RelationshipTier: &tier,
	})
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d", resp.StatusCode)
	}
	var out map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&out)
	if out["relationship_tier"] != "close" {
		t.Fatalf("expected relationship_tier close, got %v", out)
	}
	if out["autonomy_level"] != "L1" {
		t.Fatalf("expected autonomy_level L1, got %v", out)
	}
}

func TestPatchTwinSettingsRejectsInvalidRelationshipTier(t *testing.T) {
	server, _ := setupTestServer(t)
	userID, token := mustSignup(t, server.URL, "민수")

	bad := RelationshipTier("aloof")
	resp := patchJSONAuth(t, server.URL+"/users/"+strconv.FormatUint(uint64(userID), 10)+"/twin-settings", token, updateTwinSettingsRequest{
		AutonomyLevel:    AutonomyL0,
		RelationshipTier: &bad,
	})
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", resp.StatusCode)
	}
}

func TestPatchTwinSettingsOmittingTierLeavesItUnchanged(t *testing.T) {
	server, _ := setupTestServer(t)
	userID, token := mustSignup(t, server.URL, "민수")
	userIDStr := strconv.FormatUint(uint64(userID), 10)

	tier := RelationshipClose
	patchJSONAuth(t, server.URL+"/users/"+userIDStr+"/twin-settings", token, updateTwinSettingsRequest{
		AutonomyLevel:    AutonomyL1,
		RelationshipTier: &tier,
	})

	// Existing autonomy-only callers must keep working exactly as before --
	// omitting relationship_tier must not reset it back to the DB default.
	resp := patchJSONAuth(t, server.URL+"/users/"+userIDStr+"/twin-settings", token, updateTwinSettingsRequest{
		AutonomyLevel: AutonomyL2,
	})
	var out map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&out)
	if out["relationship_tier"] != "close" {
		t.Fatalf("expected relationship_tier to stay close, got %v", out)
	}
}

func TestContactRelationshipTierOverridesGlobalDefaultInDraft(t *testing.T) {
	server, _ := setupTestServer(t)
	ownerID, ownerToken := mustSignup(t, server.URL, "민수")
	peerID, _ := mustSignup(t, server.URL, "철수")

	// Global default starts as "formal" (signup default). Override just
	// this contact to "close".
	closeTier := RelationshipClose
	contactResp := postJSONAuth(t, server.URL+"/users/"+strconv.FormatUint(uint64(ownerID), 10)+"/contacts", ownerToken, createContactRequest{
		DisplayName:      "철수",
		ContactUserID:    &peerID,
		RelationshipTier: &closeTier,
	})
	if contactResp.StatusCode != http.StatusOK {
		t.Fatalf("create contact: %d", contactResp.StatusCode)
	}

	convResp := postJSONAuth(t, server.URL+"/conversations", ownerToken, createConversationRequest{
		UserIDs: []uint{ownerID, peerID},
	})
	var conv map[string]interface{}
	json.NewDecoder(convResp.Body).Decode(&conv)
	convID := uint(conv["id"].(float64))

	draftResp := postJSONAuth(t, server.URL+"/conversations/"+strconv.FormatUint(uint64(convID), 10)+"/draft", ownerToken, draftMessageRequest{
		ContextLines:  []string{"상대: 오늘 저녁에 뭐 먹을래?"},
		StyleExamples: []string{"ㅇㅇ 좋지"},
	})
	if draftResp.StatusCode != http.StatusOK {
		t.Fatalf("draft: %d", draftResp.StatusCode)
	}
	var draftOut draftResponse
	json.NewDecoder(draftResp.Body).Decode(&draftOut)
	if !strings.Contains(draftOut.Text, "tier=close") {
		t.Fatalf("expected contact override tier=close in mock draft, got %v", draftOut.Text)
	}
}

func TestDraftFallsBackToGlobalTierWithoutContactOverride(t *testing.T) {
	server, _ := setupTestServer(t)
	ownerID, ownerToken := mustSignup(t, server.URL, "민수")
	peerID, _ := mustSignup(t, server.URL, "철수")

	// No contact record at all -- resolveRelationshipTier must fall back to
	// the signup default ("formal") rather than erroring.
	convResp := postJSONAuth(t, server.URL+"/conversations", ownerToken, createConversationRequest{
		UserIDs: []uint{ownerID, peerID},
	})
	var conv map[string]interface{}
	json.NewDecoder(convResp.Body).Decode(&conv)
	convID := uint(conv["id"].(float64))

	draftResp := postJSONAuth(t, server.URL+"/conversations/"+strconv.FormatUint(uint64(convID), 10)+"/draft", ownerToken, draftMessageRequest{
		ContextLines:  []string{"상대: 내일 시간 되세요?"},
		StyleExamples: []string{"네 됩니다"},
	})
	var draftOut draftResponse
	json.NewDecoder(draftResp.Body).Decode(&draftOut)
	if !strings.Contains(draftOut.Text, "tier=formal") {
		t.Fatalf("expected global default tier=formal in mock draft, got %v", draftOut.Text)
	}
}

func TestDraftWithoutAuthDefaultsToFormalTier(t *testing.T) {
	server, db := setupTestServer(t)
	conv := Conversation{IsGroup: false}
	if err := db.Create(&conv).Error; err != nil {
		t.Fatalf("create conversation: %v", err)
	}

	// No Authorization header at all -- this endpoint has never required
	// one, so it must keep working (just without tier personalization).
	resp := postJSON(t, server.URL+"/conversations/"+strconv.FormatUint(uint64(conv.ID), 10)+"/draft", draftMessageRequest{
		ContextLines:  []string{"상대: 오늘 저녁에 뭐 먹을래?"},
		StyleExamples: []string{"ㅇㅇ 좋지"},
	})
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d", resp.StatusCode)
	}
	var out draftResponse
	json.NewDecoder(resp.Body).Decode(&out)
	if !strings.Contains(out.Text, "tier=formal") {
		t.Fatalf("expected default tier=formal for unauthenticated call, got %v", out.Text)
	}
}

func TestContactRelationshipNoteReachesDraftRequest(t *testing.T) {
	server, _ := setupTestServer(t)
	ownerID, ownerToken := mustSignup(t, server.URL, "민수")
	peerID, _ := mustSignup(t, server.URL, "철수")

	contactResp := postJSONAuth(t, server.URL+"/users/"+strconv.FormatUint(uint64(ownerID), 10)+"/contacts", ownerToken, createContactRequest{
		DisplayName:      "철수",
		ContactUserID:    &peerID,
		RelationshipNote: "호칭: 자기야, 절대 언급 금지: 전 여친",
	})
	if contactResp.StatusCode != http.StatusOK {
		t.Fatalf("create contact: %d", contactResp.StatusCode)
	}

	convResp := postJSONAuth(t, server.URL+"/conversations", ownerToken, createConversationRequest{
		UserIDs: []uint{ownerID, peerID},
	})
	var conv map[string]interface{}
	json.NewDecoder(convResp.Body).Decode(&conv)
	convID := uint(conv["id"].(float64))

	draftResp := postJSONAuth(t, server.URL+"/conversations/"+strconv.FormatUint(uint64(convID), 10)+"/draft", ownerToken, draftMessageRequest{
		ContextLines:  []string{"상대: 자기야 오늘 뭐해?"},
		StyleExamples: []string{"응 그냥 집이야"},
	})
	if draftResp.StatusCode != http.StatusOK {
		t.Fatalf("draft: %d", draftResp.StatusCode)
	}
	var draftOut draftResponse
	json.NewDecoder(draftResp.Body).Decode(&draftOut)
	if !strings.Contains(draftOut.Text, "[note=호칭: 자기야, 절대 언급 금지: 전 여친]") {
		t.Fatalf("expected contact relationship note forwarded in mock draft, got %v", draftOut.Text)
	}
}

func TestDraftWithoutRelationshipNoteHasNoNoteText(t *testing.T) {
	server, _ := setupTestServer(t)
	ownerID, ownerToken := mustSignup(t, server.URL, "민수")
	peerID, _ := mustSignup(t, server.URL, "철수")

	// Contact exists but with no RelationshipNote set (empty string, the
	// zero value) -- must resolve to "" rather than injecting anything.
	postJSONAuth(t, server.URL+"/users/"+strconv.FormatUint(uint64(ownerID), 10)+"/contacts", ownerToken, createContactRequest{
		DisplayName:   "철수",
		ContactUserID: &peerID,
	})

	convResp := postJSONAuth(t, server.URL+"/conversations", ownerToken, createConversationRequest{
		UserIDs: []uint{ownerID, peerID},
	})
	var conv map[string]interface{}
	json.NewDecoder(convResp.Body).Decode(&conv)
	convID := uint(conv["id"].(float64))

	draftResp := postJSONAuth(t, server.URL+"/conversations/"+strconv.FormatUint(uint64(convID), 10)+"/draft", ownerToken, draftMessageRequest{
		ContextLines:  []string{"상대: 내일 시간 되세요?"},
		StyleExamples: []string{"네 됩니다"},
	})
	var draftOut draftResponse
	json.NewDecoder(draftResp.Body).Decode(&draftOut)
	if !strings.Contains(draftOut.Text, "[note=]") {
		t.Fatalf("expected empty note to produce no note text, got %v", draftOut.Text)
	}
}

func TestGroupConversationDraftAlwaysGetsEmptyNoteRegardlessOfContactNote(t *testing.T) {
	server, _ := setupTestServer(t)
	ownerID, ownerToken := mustSignup(t, server.URL, "민수")
	peerID, _ := mustSignup(t, server.URL, "철수")

	// A 1:1 relationship note exists for this same pair of users elsewhere,
	// but a group conversation has more than one counterpart -- there is no
	// single "the note" to pick, so it must always resolve to "".
	postJSONAuth(t, server.URL+"/users/"+strconv.FormatUint(uint64(ownerID), 10)+"/contacts", ownerToken, createContactRequest{
		DisplayName:      "철수",
		ContactUserID:    &peerID,
		RelationshipNote: "호칭: 자기야",
	})

	convID := createGroup(t, server.URL, ownerToken, []uint{ownerID, peerID})

	draftResp := postJSONAuth(t, server.URL+"/conversations/"+strconv.FormatUint(uint64(convID), 10)+"/draft", ownerToken, draftMessageRequest{
		ContextLines:  []string{"철수: 이번 주 토요일 모임 어때?"},
		StyleExamples: []string{"ㅇㅇ 좋지"},
	})
	var draftOut draftResponse
	json.NewDecoder(draftResp.Body).Decode(&draftOut)
	if !strings.Contains(draftOut.Text, "[note=]") {
		t.Fatalf("expected group draft to always get empty note despite existing 1:1 contact note, got %v", draftOut.Text)
	}
}

func TestGroupConversationDraftUsesGlobalTierNotContactOverride(t *testing.T) {
	server, _ := setupTestServer(t)
	ownerID, ownerToken := mustSignup(t, server.URL, "민수")
	peerID, _ := mustSignup(t, server.URL, "철수")

	closeTier := RelationshipClose
	postJSONAuth(t, server.URL+"/users/"+strconv.FormatUint(uint64(ownerID), 10)+"/contacts", ownerToken, createContactRequest{
		DisplayName:      "철수",
		ContactUserID:    &peerID,
		RelationshipTier: &closeTier,
	})

	convID := createGroup(t, server.URL, ownerToken, []uint{ownerID, peerID})

	draftResp := postJSONAuth(t, server.URL+"/conversations/"+strconv.FormatUint(uint64(convID), 10)+"/draft", ownerToken, draftMessageRequest{
		ContextLines:  []string{"철수: 이번 주 토요일 모임 어때?"},
		StyleExamples: []string{"ㅇㅇ 좋지"},
	})
	var draftOut draftResponse
	json.NewDecoder(draftResp.Body).Decode(&draftOut)
	// Group conversations ignore the per-contact override (roadmap.md
	// §2.7-B: a group has more than one counterpart) and use the global
	// default ("formal") instead.
	if !strings.Contains(draftOut.Text, "tier=formal") {
		t.Fatalf("expected group draft to use global tier=formal, got %v", draftOut.Text)
	}
}

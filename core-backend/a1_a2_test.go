package main

import (
	"encoding/json"
	"net/http"
	"strconv"
	"testing"
)

func TestInvitesRequireAdminToken(t *testing.T) {
	server, _ := setupTestServer(t)
	resp := postJSON(t, server.URL+"/invites", nil)
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("expected 401 without admin token, got %d", resp.StatusCode)
	}
}

func TestLoginReturnsSessionToken(t *testing.T) {
	server, _ := setupTestServer(t)
	code := mintInvite(t, server.URL)
	signup := postJSON(t, server.URL+"/auth/signup", signupRequest{InviteCode: code, DisplayName: "로그인"})
	if signup.StatusCode != http.StatusOK {
		t.Fatalf("signup: %d", signup.StatusCode)
	}

	login := postJSON(t, server.URL+"/auth/login", loginRequest{InviteCode: code})
	if login.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 login, got %d", login.StatusCode)
	}
	var out map[string]interface{}
	json.NewDecoder(login.Body).Decode(&out)
	if out["token"] == nil || out["token"] == "" {
		t.Fatalf("login missing token: %v", out)
	}
}

func TestConversationContactMessageHistoryAndEscalationLogs(t *testing.T) {
	server, _ := setupTestServer(t)
	ownerID, ownerToken := mustSignup(t, server.URL, "주인")
	peerID, _ := mustSignup(t, server.URL, "상대")

	// Create contact linking peer user.
	contactResp := postJSONAuth(t, server.URL+"/users/"+strconv.FormatUint(uint64(ownerID), 10)+"/contacts", ownerToken, createContactRequest{
		DisplayName:   "상대방",
		ContactUserID: &peerID,
	})
	if contactResp.StatusCode != http.StatusOK {
		t.Fatalf("create contact: %d", contactResp.StatusCode)
	}
	var contact map[string]interface{}
	json.NewDecoder(contactResp.Body).Decode(&contact)
	contactID := uint(contact["id"].(float64))

	convResp := postJSONAuth(t, server.URL+"/conversations", ownerToken, createConversationRequest{
		UserIDs:   []uint{ownerID, peerID},
		ContactID: &contactID,
	})
	if convResp.StatusCode != http.StatusOK {
		t.Fatalf("create conversation: %d", convResp.StatusCode)
	}
	var conv map[string]interface{}
	json.NewDecoder(convResp.Body).Decode(&conv)
	convID := uint(conv["id"].(float64))

	listResp, _ := http.NewRequest(http.MethodGet, server.URL+"/conversations", nil)
	listResp.Header.Set("Authorization", "Bearer "+ownerToken)
	listed, err := http.DefaultClient.Do(listResp)
	if err != nil {
		t.Fatal(err)
	}
	var listOut map[string]interface{}
	json.NewDecoder(listed.Body).Decode(&listOut)
	convs := listOut["conversations"].([]interface{})
	if len(convs) != 1 {
		t.Fatalf("expected 1 conversation, got %v", listOut)
	}

	postJSON(t, server.URL+"/conversations/"+strconv.FormatUint(uint64(convID), 10)+"/messages", sendMessageRequest{
		SenderID: ownerID,
		Text:     "안녕 저녁 어때",
	})

	histReq, _ := http.NewRequest(http.MethodGet, server.URL+"/conversations/"+strconv.FormatUint(uint64(convID), 10)+"/messages", nil)
	histReq.Header.Set("Authorization", "Bearer "+ownerToken)
	histResp, err := http.DefaultClient.Do(histReq)
	if err != nil {
		t.Fatal(err)
	}
	if histResp.StatusCode != http.StatusOK {
		t.Fatalf("history: %d", histResp.StatusCode)
	}
	var hist map[string]interface{}
	json.NewDecoder(histResp.Body).Decode(&hist)
	if len(hist["messages"].([]interface{})) != 1 {
		t.Fatalf("expected 1 message, got %v", hist)
	}

	// Force an escalation log via twin send.
	setAutonomyLevel(t, server.URL, ownerID, ownerToken, AutonomyL1)
	postJSON(t, server.URL+"/conversations/"+strconv.FormatUint(uint64(convID), 10)+"/messages", sendMessageRequest{
		SenderID:   ownerID,
		Text:       "계좌번호 알려줄게",
		SenderMode: SenderTwin,
		Approved:   true,
	})

	logReq, _ := http.NewRequest(http.MethodGet, server.URL+"/users/"+strconv.FormatUint(uint64(ownerID), 10)+"/escalation-logs", nil)
	logReq.Header.Set("Authorization", "Bearer "+ownerToken)
	logResp, err := http.DefaultClient.Do(logReq)
	if err != nil {
		t.Fatal(err)
	}
	if logResp.StatusCode != http.StatusOK {
		t.Fatalf("escalation logs: %d", logResp.StatusCode)
	}
	var logs map[string]interface{}
	json.NewDecoder(logResp.Body).Decode(&logs)
	if len(logs["escalation_logs"].([]interface{})) < 1 {
		t.Fatalf("expected escalation log, got %v", logs)
	}
}

func TestContactScopedWhitelistMatch(t *testing.T) {
	server, db := setupTestServer(t)
	ownerID, ownerToken := mustSignup(t, server.URL, "화이트주인")
	peerID, _ := mustSignup(t, server.URL, "화이트상대")
	otherID, _ := mustSignup(t, server.URL, "다른사람")

	contactResp := postJSONAuth(t, server.URL+"/users/"+strconv.FormatUint(uint64(ownerID), 10)+"/contacts", ownerToken, createContactRequest{
		DisplayName:   "상대",
		ContactUserID: &peerID,
	})
	var contact map[string]interface{}
	json.NewDecoder(contactResp.Body).Decode(&contact)
	contactID := uint(contact["id"].(float64))

	// Rule only for this contact + keyword 저녁
	cid := contactID
	postJSONAuth(t, server.URL+"/users/"+strconv.FormatUint(uint64(ownerID), 10)+"/whitelist-rules", ownerToken, createWhitelistRuleRequest{
		ContactID:    &cid,
		TopicKeyword: "저녁",
	})
	setAutonomyLevel(t, server.URL, ownerID, ownerToken, AutonomyL2)

	// Conversation with the whitelisted peer -- should auto-send.
	convPeer := postJSONAuth(t, server.URL+"/conversations", ownerToken, createConversationRequest{
		UserIDs:   []uint{ownerID, peerID},
		ContactID: &contactID,
	})
	var conv1 map[string]interface{}
	json.NewDecoder(convPeer.Body).Decode(&conv1)
	conv1ID := uint(conv1["id"].(float64))

	okResp := postJSON(t, server.URL+"/conversations/"+strconv.FormatUint(uint64(conv1ID), 10)+"/messages", sendMessageRequest{
		SenderID:   ownerID,
		Text:       "오늘 저녁 뭐 먹을래",
		SenderMode: SenderTwin,
	})
	if okResp.StatusCode != http.StatusOK {
		t.Fatalf("expected L2 auto-send for matching contact+keyword, got %d", okResp.StatusCode)
	}

	// Conversation with a different peer -- same keyword must NOT match contact-scoped rule.
	convOther := postJSONAuth(t, server.URL+"/conversations", ownerToken, createConversationRequest{
		UserIDs: []uint{ownerID, otherID},
	})
	var conv2 map[string]interface{}
	json.NewDecoder(convOther.Body).Decode(&conv2)
	conv2ID := uint(conv2["id"].(float64))

	blocked := postJSON(t, server.URL+"/conversations/"+strconv.FormatUint(uint64(conv2ID), 10)+"/messages", sendMessageRequest{
		SenderID:   ownerID,
		Text:       "오늘 저녁 뭐 먹을래",
		SenderMode: SenderTwin,
	})
	if blocked.StatusCode != http.StatusForbidden {
		t.Fatalf("expected 403 when contact-scoped rule does not apply, got %d", blocked.StatusCode)
	}

	var n int64
	db.Model(&Message{}).Where("conversation_id = ? AND sender_mode = ?", conv2ID, SenderTwin).Count(&n)
	if n != 0 {
		t.Fatalf("must not store twin message for non-matching contact, got %d", n)
	}
}

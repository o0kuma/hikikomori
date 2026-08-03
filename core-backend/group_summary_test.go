package main

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"
	"testing"
)

func createGroup(t *testing.T, serverURL, token string, userIDs []uint) uint {
	t.Helper()
	resp := postJSONAuth(t, serverURL+"/conversations", token, createConversationRequest{
		UserIDs: userIDs,
		IsGroup: true,
	})
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("create group: %d", resp.StatusCode)
	}
	var out map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&out)
	return uint(out["id"].(float64))
}

func TestGroupConversationBlocksTwinAutoSendRegardlessOfAutonomyLevel(t *testing.T) {
	server, _ := setupTestServer(t)
	ownerID, ownerToken := mustSignup(t, server.URL, "주인")
	peerID, _ := mustSignup(t, server.URL, "친구")
	convID := createGroup(t, server.URL, ownerToken, []uint{ownerID, peerID})

	// L2 with a matching whitelist rule would normally auto-send in a 1:1
	// conversation (main_test.go's autonomy flow tests cover that) -- group
	// conversations must block twin sends outright regardless (PRD.md
	// §2.3-③, roadmap.md §2.7-A: "이 시나리오는 L0 고정, 자동 발송 없음").
	setAutonomyLevel(t, server.URL, ownerID, ownerToken, AutonomyL2)

	resp := postJSONAuth(t, server.URL+"/conversations/"+strconv.FormatUint(uint64(convID), 10)+"/messages", ownerToken, sendMessageRequest{
		SenderID:   ownerID,
		Text:       "ㅇㅋ 알겠음",
		SenderMode: SenderTwin,
		Approved:   true,
	})
	if resp.StatusCode != http.StatusForbidden {
		t.Fatalf("expected 403 blocking twin send in group, got %d", resp.StatusCode)
	}

	// A human-authored send in the same group is unaffected.
	humanResp := postJSONAuth(t, server.URL+"/conversations/"+strconv.FormatUint(uint64(convID), 10)+"/messages", ownerToken, sendMessageRequest{
		SenderID: ownerID,
		Text:     "내가 직접 씀",
	})
	if humanResp.StatusCode != http.StatusOK {
		t.Fatalf("expected human send to succeed, got %d", humanResp.StatusCode)
	}
}

func TestGroupSummaryReflectsUnreadSinceReadMarker(t *testing.T) {
	server, _ := setupTestServer(t)
	ownerID, ownerToken := mustSignup(t, server.URL, "민수")
	peerID, _ := mustSignup(t, server.URL, "철수")
	convID := createGroup(t, server.URL, ownerToken, []uint{ownerID, peerID})
	convIDStr := strconv.FormatUint(uint64(convID), 10)

	// Nothing read yet -- summary should be empty (no messages at all).
	emptyResp, _ := http.NewRequest(http.MethodGet, server.URL+"/conversations/"+convIDStr+"/summary", nil)
	emptyResp.Header.Set("Authorization", "Bearer "+ownerToken)
	emptyOut, err := http.DefaultClient.Do(emptyResp)
	if err != nil {
		t.Fatalf("get summary: %v", err)
	}
	var emptyBody map[string]interface{}
	json.NewDecoder(emptyOut.Body).Decode(&emptyBody)
	if emptyBody["status"] != "empty" {
		t.Fatalf("expected empty status with no messages, got %v", emptyBody)
	}

	// Peer sends two messages the owner hasn't read.
	postJSONAuth(t, server.URL+"/conversations/"+convIDStr+"/messages", ownerToken, sendMessageRequest{
		SenderID: peerID, Text: "토요일 모임 3시 어때?",
	})
	postJSONAuth(t, server.URL+"/conversations/"+convIDStr+"/messages", ownerToken, sendMessageRequest{
		SenderID: peerID, Text: "민수야 답장 좀",
	})

	sumReq, _ := http.NewRequest(http.MethodGet, server.URL+"/conversations/"+convIDStr+"/summary", nil)
	sumReq.Header.Set("Authorization", "Bearer "+ownerToken)
	sumResp, err := http.DefaultClient.Do(sumReq)
	if err != nil {
		t.Fatalf("get summary: %v", err)
	}
	var sumBody map[string]interface{}
	json.NewDecoder(sumResp.Body).Decode(&sumBody)
	if sumBody["status"] != "ok" {
		t.Fatalf("expected ok status, got %v", sumBody)
	}
	if int(sumBody["unread_count"].(float64)) != 2 {
		t.Fatalf("expected 2 unread, got %v", sumBody["unread_count"])
	}
	if sumBody["needs_reply"] != true {
		t.Fatalf("expected needs_reply true, got %v", sumBody["needs_reply"])
	}
	summaryText := sumBody["summary"].(string)
	if !containsAll(summaryText, "토요일 모임 3시 어때", "민수야 답장 좀") {
		t.Fatalf("summary missing unread content: %v", summaryText)
	}

	// List conversations should report the same unread count.
	listReq, _ := http.NewRequest(http.MethodGet, server.URL+"/conversations", nil)
	listReq.Header.Set("Authorization", "Bearer "+ownerToken)
	listResp, err := http.DefaultClient.Do(listReq)
	if err != nil {
		t.Fatalf("list conversations: %v", err)
	}
	var listBody map[string]interface{}
	json.NewDecoder(listResp.Body).Decode(&listBody)
	convs := listBody["conversations"].([]interface{})
	found := false
	for _, raw := range convs {
		c := raw.(map[string]interface{})
		if uint(c["id"].(float64)) == convID {
			found = true
			if int(c["unread_count"].(float64)) != 2 {
				t.Fatalf("expected list unread_count 2, got %v", c["unread_count"])
			}
		}
	}
	if !found {
		t.Fatalf("conversation %d not found in list", convID)
	}

	// Mark read up to the latest message, then re-fetch: should be empty
	// again and the list's unread_count should drop to 0.
	var msgs map[string]interface{}
	msgsReq, _ := http.NewRequest(http.MethodGet, server.URL+"/conversations/"+convIDStr+"/messages", nil)
	msgsReq.Header.Set("Authorization", "Bearer "+ownerToken)
	msgsResp, _ := http.DefaultClient.Do(msgsReq)
	json.NewDecoder(msgsResp.Body).Decode(&msgs)
	msgList := msgs["messages"].([]interface{})
	lastID := uint(msgList[len(msgList)-1].(map[string]interface{})["id"].(float64))

	readResp := postJSONAuth(t, server.URL+"/conversations/"+convIDStr+"/read", ownerToken, map[string]interface{}{"message_id": lastID})
	if readResp.StatusCode != http.StatusOK {
		t.Fatalf("mark read: %d", readResp.StatusCode)
	}

	afterReq, _ := http.NewRequest(http.MethodGet, server.URL+"/conversations/"+convIDStr+"/summary", nil)
	afterReq.Header.Set("Authorization", "Bearer "+ownerToken)
	afterResp, _ := http.DefaultClient.Do(afterReq)
	var afterBody map[string]interface{}
	json.NewDecoder(afterResp.Body).Decode(&afterBody)
	if afterBody["status"] != "empty" {
		t.Fatalf("expected empty summary after marking read, got %v", afterBody)
	}
}

func containsAll(haystack string, needles ...string) bool {
	for _, n := range needles {
		if !strings.Contains(haystack, n) {
			return false
		}
	}
	return true
}

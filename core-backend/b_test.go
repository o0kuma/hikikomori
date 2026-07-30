package main

import (
	"encoding/json"
	"net/http"
	"strconv"
	"testing"
)

func TestMessageCreateReturnsFullPayload(t *testing.T) {
	server, _ := setupTestServer(t)
	userID, token := mustSignup(t, server.URL, "full-msg")
	peerID, _ := mustSignup(t, server.URL, "full-msg-peer")

	convResp := postJSONAuth(t, server.URL+"/conversations", token, createConversationRequest{
		UserIDs: []uint{userID, peerID},
	})
	if convResp.StatusCode != http.StatusOK {
		t.Fatalf("create conversation: %d", convResp.StatusCode)
	}
	var conv map[string]interface{}
	json.NewDecoder(convResp.Body).Decode(&conv)
	convID := uint(conv["id"].(float64))

	msgResp := postJSON(t, server.URL+"/conversations/"+strconv.FormatUint(uint64(convID), 10)+"/messages", sendMessageRequest{
		SenderID: userID,
		Text:     "hello full",
	})
	if msgResp.StatusCode != http.StatusOK {
		t.Fatalf("send: %d", msgResp.StatusCode)
	}
	var out map[string]interface{}
	json.NewDecoder(msgResp.Body).Decode(&out)
	for _, key := range []string{"id", "conversation_id", "sender_id", "sender_mode", "text", "retracted"} {
		if _, ok := out[key]; !ok {
			t.Fatalf("missing key %s in %v", key, out)
		}
	}
	if out["text"] != "hello full" || out["sender_mode"] != "human" {
		t.Fatalf("unexpected payload %v", out)
	}
}

func TestDeviceTokenAndSessions(t *testing.T) {
	server, _ := setupTestServer(t)
	userID, token := mustSignup(t, server.URL, "devices")

	reg := postJSONAuth(t, server.URL+"/users/"+strconv.FormatUint(uint64(userID), 10)+"/device-tokens", token, registerDeviceRequest{
		Token:    "fcm-test-token-abc",
		Platform: "android",
	})
	if reg.StatusCode != http.StatusOK {
		t.Fatalf("device token: %d", reg.StatusCode)
	}

	req, _ := http.NewRequest(http.MethodGet, server.URL+"/users/"+strconv.FormatUint(uint64(userID), 10)+"/sessions", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	var sout map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&sout)
	sessions := sout["sessions"].([]interface{})
	if len(sessions) < 1 {
		t.Fatalf("expected at least one session, got %v", sout)
	}
	first := sessions[0].(map[string]interface{})
	if first["is_current"] != true {
		t.Fatalf("expected current session flag, got %v", first)
	}
}

func TestAdminMetricsIncludesDraftLatencyFields(t *testing.T) {
	server, _ := setupTestServer(t)
	req, _ := http.NewRequest(http.MethodGet, server.URL+"/admin/metrics", nil)
	req.Header.Set("Authorization", "Bearer test-admin-token")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	var out map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&out)
	for _, key := range []string{"draft_requests", "draft_error_rate", "draft_latency_avg_ms", "escalate_error_rate"} {
		if _, ok := out[key]; !ok {
			t.Fatalf("missing metrics key %s in %v", key, out)
		}
	}
}

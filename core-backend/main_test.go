package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"strconv"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

// mockAIService stands in for ai-service/ during tests -- it echoes back
// a canned response so core-backend's HTTP client code (not the Python
// service itself) is what's under test here.
func mockAIService(t *testing.T) *httptest.Server {
	t.Helper()
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/draft" {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		var req draftRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(draftResponse{Status: "ok", Text: "mock draft for: " + strings.Join(req.ContextLines, " | ")})
	}))
	t.Cleanup(server.Close)
	return server
}

func setupTestServer(t *testing.T) (*httptest.Server, *gorm.DB) {
	t.Helper()
	dbPath := t.TempDir() + "/test.db"
	db, err := gorm.Open(sqlite.Open(dbPath), &gorm.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	if err := db.AutoMigrate(allModels...); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	ai := &AIServiceClient{BaseURL: mockAIService(t).URL, HTTP: http.DefaultClient}

	gin.SetMode(gin.TestMode)
	router := setupRouter(db, newConnectionManager(), ai)
	server := httptest.NewServer(router)
	t.Cleanup(server.Close)
	return server, db
}

func postJSON(t *testing.T, url string, body interface{}) *http.Response {
	t.Helper()
	b, _ := json.Marshal(body)
	resp, err := http.Post(url, "application/json", bytes.NewReader(b))
	if err != nil {
		t.Fatalf("post %s: %v", url, err)
	}
	return resp
}

func TestHealth(t *testing.T) {
	server, _ := setupTestServer(t)
	resp, err := http.Get(server.URL + "/health")
	if err != nil {
		t.Fatal(err)
	}
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d", resp.StatusCode)
	}
}

func TestSignupAndDuplicateRejected(t *testing.T) {
	server, _ := setupTestServer(t)

	resp := postJSON(t, server.URL+"/auth/signup", signupRequest{InviteCode: "abc123", DisplayName: "지우"})
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d", resp.StatusCode)
	}
	var out map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&out)
	if out["display_name"] != "지우" {
		t.Fatalf("unexpected body: %v", out)
	}

	dup := postJSON(t, server.URL+"/auth/signup", signupRequest{InviteCode: "abc123", DisplayName: "dup"})
	if dup.StatusCode != http.StatusConflict {
		t.Fatalf("expected 409 for duplicate invite_code, got %d", dup.StatusCode)
	}
}

func TestSendMessageToMissingConversation(t *testing.T) {
	server, _ := setupTestServer(t)
	resp := postJSON(t, server.URL+"/conversations/9999/messages", sendMessageRequest{SenderID: 1, Text: "hi"})
	if resp.StatusCode != http.StatusNotFound {
		t.Fatalf("expected 404, got %d", resp.StatusCode)
	}
}

func TestSendMessageAndWebSocketBroadcast(t *testing.T) {
	server, db := setupTestServer(t)

	signupResp := postJSON(t, server.URL+"/auth/signup", signupRequest{InviteCode: "sender1", DisplayName: "정우"})
	var user map[string]interface{}
	json.NewDecoder(signupResp.Body).Decode(&user)
	senderID := uint(user["id"].(float64))

	conv := Conversation{IsGroup: false}
	if err := db.Create(&conv).Error; err != nil {
		t.Fatalf("create conversation: %v", err)
	}

	wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "/ws/conversations/" +
		strconv.FormatUint(uint64(conv.ID), 10)
	ws, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("dial ws: %v", err)
	}
	defer ws.Close()

	sendResp := postJSON(t, server.URL+"/conversations/"+strconv.FormatUint(uint64(conv.ID), 10)+"/messages", sendMessageRequest{
		SenderID:   senderID,
		Text:       "안녕하세요",
		SenderMode: SenderTwin,
	})
	if sendResp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 sending message, got %d", sendResp.StatusCode)
	}

	var received map[string]interface{}
	if err := ws.ReadJSON(&received); err != nil {
		t.Fatalf("read ws message: %v", err)
	}
	if received["text"] != "안녕하세요" || received["sender_mode"] != "twin" {
		t.Fatalf("unexpected ws payload: %v", received)
	}
}

func TestDraftMissingConversation(t *testing.T) {
	server, _ := setupTestServer(t)
	resp := postJSON(t, server.URL+"/conversations/9999/draft", draftMessageRequest{
		ContextLines:  []string{"상대: 오늘 저녁에 뭐 먹을래?"},
		StyleExamples: []string{"ㅇㅇ 좋지"},
	})
	if resp.StatusCode != http.StatusNotFound {
		t.Fatalf("expected 404, got %d", resp.StatusCode)
	}
}

func TestDraftRequiresStyleSource(t *testing.T) {
	server, db := setupTestServer(t)
	conv := Conversation{IsGroup: false}
	if err := db.Create(&conv).Error; err != nil {
		t.Fatalf("create conversation: %v", err)
	}

	resp := postJSON(t, server.URL+"/conversations/"+strconv.FormatUint(uint64(conv.ID), 10)+"/draft", draftMessageRequest{
		ContextLines: []string{"상대: 오늘 저녁에 뭐 먹을래?"},
	})
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", resp.StatusCode)
	}
}

func TestDraftProxiesToAIService(t *testing.T) {
	server, db := setupTestServer(t)
	conv := Conversation{IsGroup: false}
	if err := db.Create(&conv).Error; err != nil {
		t.Fatalf("create conversation: %v", err)
	}

	resp := postJSON(t, server.URL+"/conversations/"+strconv.FormatUint(uint64(conv.ID), 10)+"/draft", draftMessageRequest{
		ContextLines:  []string{"상대: 오늘 저녁에 뭐 먹을래?"},
		StyleExamples: []string{"ㅇㅇ 좋지"},
	})
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d", resp.StatusCode)
	}
	var out draftResponse
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if out.Status != "ok" || !strings.Contains(out.Text, "오늘 저녁에 뭐 먹을래") {
		t.Fatalf("unexpected draft response: %+v", out)
	}
}

func TestMain(m *testing.M) {
	os.Exit(m.Run())
}

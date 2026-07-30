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

	gin.SetMode(gin.TestMode)
	router := setupRouter(db, newConnectionManager())
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

func TestMain(m *testing.M) {
	os.Exit(m.Run())
}

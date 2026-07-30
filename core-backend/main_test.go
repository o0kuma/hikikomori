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
	"time"

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
		switch r.URL.Path {
		case "/draft":
			var req draftRequest
			if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
				w.WriteHeader(http.StatusBadRequest)
				return
			}
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(draftResponse{Status: "ok", Text: "mock draft for: " + strings.Join(req.ContextLines, " | ")})
		case "/escalate/check":
			// Mirrors escalation_filter.py's rule set closely enough to
			// exercise core-backend's gating logic; the rules themselves
			// are verified against ai-service/app/escalation_filter.py directly.
			var req escalationCheckRequest
			if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
				w.WriteHeader(http.StatusBadRequest)
				return
			}
			out := escalationCheckResponse{}
			switch {
			case strings.Contains(req.Text, "계좌") || strings.Contains(req.Text, "송금"):
				out = escalationCheckResponse{Escalate: true, Reason: "금전"}
			case strings.Contains(req.Text, "힘들어"):
				out = escalationCheckResponse{Escalate: true, Reason: "감정적으로 무거운 주제"}
			}
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(out)
		default:
			w.WriteHeader(http.StatusNotFound)
		}
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

func mintInvite(t *testing.T, serverURL string) string {
	t.Helper()
	resp := postJSON(t, serverURL+"/invites", nil)
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 minting invite, got %d", resp.StatusCode)
	}
	var out map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&out)
	return out["code"].(string)
}

func mustSignup(t *testing.T, serverURL, displayName string) uint {
	t.Helper()
	resp := postJSON(t, serverURL+"/auth/signup", signupRequest{InviteCode: mintInvite(t, serverURL), DisplayName: displayName})
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 signing up %s, got %d", displayName, resp.StatusCode)
	}
	var out map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&out)
	return uint(out["id"].(float64))
}

func setAutonomyLevel(t *testing.T, serverURL string, userID uint, level AutonomyLevel) {
	t.Helper()
	body, _ := json.Marshal(updateTwinSettingsRequest{AutonomyLevel: level})
	req, _ := http.NewRequest(http.MethodPatch, serverURL+"/users/"+strconv.FormatUint(uint64(userID), 10)+"/twin-settings", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("set autonomy level: %v", err)
	}
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 setting autonomy level, got %d", resp.StatusCode)
	}
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
	code := mintInvite(t, server.URL)

	resp := postJSON(t, server.URL+"/auth/signup", signupRequest{InviteCode: code, DisplayName: "지우"})
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d", resp.StatusCode)
	}
	var out map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&out)
	if out["display_name"] != "지우" {
		t.Fatalf("unexpected body: %v", out)
	}

	dup := postJSON(t, server.URL+"/auth/signup", signupRequest{InviteCode: code, DisplayName: "dup"})
	if dup.StatusCode != http.StatusConflict {
		t.Fatalf("expected 409 for a reused invite code, got %d", dup.StatusCode)
	}
}

func TestSignupRejectsUnknownInviteCode(t *testing.T) {
	server, _ := setupTestServer(t)
	resp := postJSON(t, server.URL+"/auth/signup", signupRequest{InviteCode: "never-minted", DisplayName: "누구"})
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("expected 400 for an invite code nobody minted, got %d", resp.StatusCode)
	}
}

func TestMintInviteReturnsUniqueCodes(t *testing.T) {
	server, _ := setupTestServer(t)
	a := mintInvite(t, server.URL)
	b := mintInvite(t, server.URL)
	if a == b {
		t.Fatalf("expected distinct invite codes, got %q twice", a)
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

	senderID := mustSignup(t, server.URL, "정우")

	conv := Conversation{IsGroup: false}
	if err := db.Create(&conv).Error; err != nil {
		t.Fatalf("create conversation: %v", err)
	}

	setAutonomyLevel(t, server.URL, senderID, AutonomyL1)

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
		Approved:   true,
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

func TestTwinMessageEscalatedIsBlockedAndNotBroadcast(t *testing.T) {
	server, db := setupTestServer(t)

	senderID := mustSignup(t, server.URL, "민지")

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

	resp := postJSON(t, server.URL+"/conversations/"+strconv.FormatUint(uint64(conv.ID), 10)+"/messages", sendMessageRequest{
		SenderID:   senderID,
		Text:       "계좌번호 알려줄게",
		SenderMode: SenderTwin,
	})
	if resp.StatusCode != http.StatusForbidden {
		t.Fatalf("expected 403 for escalated twin send, got %d", resp.StatusCode)
	}

	var count int64
	db.Model(&Message{}).Where("conversation_id = ?", conv.ID).Count(&count)
	if count != 0 {
		t.Fatalf("escalated twin message must not be persisted, found %d rows", count)
	}

	var logs []EscalationLog
	db.Where("conversation_id = ?", conv.ID).Find(&logs)
	if len(logs) != 1 || logs[0].Reason != "금전" {
		t.Fatalf("expected one EscalationLog row with reason 금전, got %+v", logs)
	}

	ws.SetReadDeadline(time.Now().Add(200 * time.Millisecond))
	if _, _, err := ws.ReadMessage(); err == nil {
		t.Fatal("expected no broadcast for a blocked escalated message")
	}
}

// The four tests below cover PRD.md §2.1/§2.2's L0->L1->L2 autonomy flow:
// L0 (기본값) never auto-sends, L1 requires explicit approval, L2 auto-sends
// only for whitelisted topics and otherwise behaves like L1.

func TestTwinSendBlockedAtDefaultL0(t *testing.T) {
	server, db := setupTestServer(t)

	senderID := mustSignup(t, server.URL, "하늘")

	conv := Conversation{IsGroup: false}
	if err := db.Create(&conv).Error; err != nil {
		t.Fatalf("create conversation: %v", err)
	}

	// New users default to L0 (PRD.md §2.1) -- a non-escalating twin send
	// must still be blocked, since L0 means no auto-send at all.
	resp := postJSON(t, server.URL+"/conversations/"+strconv.FormatUint(uint64(conv.ID), 10)+"/messages", sendMessageRequest{
		SenderID:   senderID,
		Text:       "ㅇㅇ 알겠어",
		SenderMode: SenderTwin,
	})
	if resp.StatusCode != http.StatusForbidden {
		t.Fatalf("expected 403 blocking twin auto-send at L0, got %d", resp.StatusCode)
	}

	var count int64
	db.Model(&Message{}).Where("conversation_id = ?", conv.ID).Count(&count)
	if count != 0 {
		t.Fatalf("L0 must never persist a twin auto-send, found %d rows", count)
	}
}

func TestTwinSendRequiresApprovalAtL1(t *testing.T) {
	server, db := setupTestServer(t)

	senderID := mustSignup(t, server.URL, "서준")
	setAutonomyLevel(t, server.URL, senderID, AutonomyL1)

	conv := Conversation{IsGroup: false}
	if err := db.Create(&conv).Error; err != nil {
		t.Fatalf("create conversation: %v", err)
	}
	convPath := server.URL + "/conversations/" + strconv.FormatUint(uint64(conv.ID), 10) + "/messages"

	unapproved := postJSON(t, convPath, sendMessageRequest{SenderID: senderID, Text: "ㅇㅇ 알겠어", SenderMode: SenderTwin})
	if unapproved.StatusCode != http.StatusForbidden {
		t.Fatalf("expected 403 without approval at L1, got %d", unapproved.StatusCode)
	}

	approved := postJSON(t, convPath, sendMessageRequest{SenderID: senderID, Text: "ㅇㅇ 알겠어", SenderMode: SenderTwin, Approved: true})
	if approved.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 with approval at L1, got %d", approved.StatusCode)
	}

	var count int64
	db.Model(&Message{}).Where("conversation_id = ?", conv.ID).Count(&count)
	if count != 1 {
		t.Fatalf("expected exactly 1 persisted message (the approved one), got %d", count)
	}
}

func TestTwinSendAutoSendsAtL2WithWhitelistMatch(t *testing.T) {
	server, db := setupTestServer(t)

	senderID := mustSignup(t, server.URL, "가은")
	setAutonomyLevel(t, server.URL, senderID, AutonomyL2)
	db.Create(&WhitelistRule{UserID: senderID, TopicKeyword: "저녁"})

	conv := Conversation{IsGroup: false}
	if err := db.Create(&conv).Error; err != nil {
		t.Fatalf("create conversation: %v", err)
	}

	// No approved:true -- L2 + whitelist match should auto-send without it.
	resp := postJSON(t, server.URL+"/conversations/"+strconv.FormatUint(uint64(conv.ID), 10)+"/messages", sendMessageRequest{
		SenderID: senderID, Text: "저녁 뭐 먹었어?", SenderMode: SenderTwin,
	})
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 auto-sending whitelisted topic at L2, got %d", resp.StatusCode)
	}

	var count int64
	db.Model(&Message{}).Where("conversation_id = ?", conv.ID).Count(&count)
	if count != 1 {
		t.Fatalf("expected 1 auto-sent message, got %d", count)
	}
}

func TestTwinSendRequiresApprovalAtL2WithoutWhitelistMatch(t *testing.T) {
	server, db := setupTestServer(t)

	senderID := mustSignup(t, server.URL, "도윤")
	setAutonomyLevel(t, server.URL, senderID, AutonomyL2)
	db.Create(&WhitelistRule{UserID: senderID, TopicKeyword: "저녁"})

	conv := Conversation{IsGroup: false}
	if err := db.Create(&conv).Error; err != nil {
		t.Fatalf("create conversation: %v", err)
	}
	convPath := server.URL + "/conversations/" + strconv.FormatUint(uint64(conv.ID), 10) + "/messages"

	// Text doesn't match any whitelist keyword -- L2 falls back to L1
	// behavior (approval required), it does not just allow or just block.
	unapproved := postJSON(t, convPath, sendMessageRequest{SenderID: senderID, Text: "주말에 영화 볼래?", SenderMode: SenderTwin})
	if unapproved.StatusCode != http.StatusForbidden {
		t.Fatalf("expected 403 for non-whitelisted topic at L2 without approval, got %d", unapproved.StatusCode)
	}

	approved := postJSON(t, convPath, sendMessageRequest{SenderID: senderID, Text: "주말에 영화 볼래?", SenderMode: SenderTwin, Approved: true})
	if approved.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 for non-whitelisted topic at L2 with approval, got %d", approved.StatusCode)
	}
}

func TestEscalationOverridesAutonomyLevelAndWhitelist(t *testing.T) {
	server, db := setupTestServer(t)

	senderID := mustSignup(t, server.URL, "은서")
	setAutonomyLevel(t, server.URL, senderID, AutonomyL2)
	// Whitelisted keyword happens to be the same word that also triggers
	// the money escalation pattern in the mock AI service.
	db.Create(&WhitelistRule{UserID: senderID, TopicKeyword: "계좌"})

	conv := Conversation{IsGroup: false}
	if err := db.Create(&conv).Error; err != nil {
		t.Fatalf("create conversation: %v", err)
	}

	resp := postJSON(t, server.URL+"/conversations/"+strconv.FormatUint(uint64(conv.ID), 10)+"/messages", sendMessageRequest{
		SenderID: senderID, Text: "계좌번호 알려줄게", SenderMode: SenderTwin, Approved: true,
	})
	if resp.StatusCode != http.StatusForbidden {
		t.Fatalf("expected 403: escalation must override L2 whitelist match and approved:true, got %d", resp.StatusCode)
	}

	var count int64
	db.Model(&Message{}).Where("conversation_id = ?", conv.ID).Count(&count)
	if count != 0 {
		t.Fatalf("escalated message must never be sent regardless of level/whitelist/approval, found %d rows", count)
	}
}

func TestHumanMessageBypassesEscalationGate(t *testing.T) {
	server, db := setupTestServer(t)

	senderID := mustSignup(t, server.URL, "재민")

	conv := Conversation{IsGroup: false}
	if err := db.Create(&conv).Error; err != nil {
		t.Fatalf("create conversation: %v", err)
	}

	// A human typing their own money-related message is never gated --
	// only unattended (twin) sends are.
	resp := postJSON(t, server.URL+"/conversations/"+strconv.FormatUint(uint64(conv.ID), 10)+"/messages", sendMessageRequest{
		SenderID:   senderID,
		Text:       "계좌번호 불러줄게",
		SenderMode: SenderHuman,
	})
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 for human-authored send, got %d", resp.StatusCode)
	}
}

func TestTwinMessageFailsClosedWhenAIServiceUnreachable(t *testing.T) {
	dbPath := t.TempDir() + "/test.db"
	db, err := gorm.Open(sqlite.Open(dbPath), &gorm.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	if err := db.AutoMigrate(allModels...); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	unreachable := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {}))
	unreachable.Close() // closed immediately -- BaseURL now points at nothing listening

	ai := &AIServiceClient{BaseURL: unreachable.URL, HTTP: http.DefaultClient}
	gin.SetMode(gin.TestMode)
	router := setupRouter(db, newConnectionManager(), ai)
	server := httptest.NewServer(router)
	t.Cleanup(server.Close)

	senderID := mustSignup(t, server.URL, "소연")

	conv := Conversation{IsGroup: false}
	if err := db.Create(&conv).Error; err != nil {
		t.Fatalf("create conversation: %v", err)
	}

	resp := postJSON(t, server.URL+"/conversations/"+strconv.FormatUint(uint64(conv.ID), 10)+"/messages", sendMessageRequest{
		SenderID:   senderID,
		Text:       "ㅇㅇ 알겠어",
		SenderMode: SenderTwin,
	})
	if resp.StatusCode != http.StatusBadGateway {
		t.Fatalf("expected 502 fail-closed when escalation gate is unreachable, got %d", resp.StatusCode)
	}

	var count int64
	db.Model(&Message{}).Where("conversation_id = ?", conv.ID).Count(&count)
	if count != 0 {
		t.Fatalf("must not persist a twin message when the safety gate couldn't be checked, found %d rows", count)
	}
}

func TestDeleteUserPurgesData(t *testing.T) {
	server, db := setupTestServer(t)

	userID := mustSignup(t, server.URL, "유나")

	conv := Conversation{IsGroup: false}
	if err := db.Create(&conv).Error; err != nil {
		t.Fatalf("create conversation: %v", err)
	}
	sendResp := postJSON(t, server.URL+"/conversations/"+strconv.FormatUint(uint64(conv.ID), 10)+"/messages", sendMessageRequest{
		SenderID: userID,
		Text:     "안녕",
	})
	if sendResp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 sending message, got %d", sendResp.StatusCode)
	}
	db.Create(&WhitelistRule{UserID: userID, TopicKeyword: "저녁 약속"})
	db.Create(&EscalationLog{UserID: userID, ConversationID: conv.ID, Reason: "금전", MessageSnippet: "..."})

	req, _ := http.NewRequest(http.MethodDelete, server.URL+"/users/"+strconv.FormatUint(uint64(userID), 10), nil)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("delete request: %v", err)
	}
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d", resp.StatusCode)
	}
	var out map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&out)
	if out["messages_deleted"].(float64) != 1 || out["escalation_logs_deleted"].(float64) != 1 {
		t.Fatalf("unexpected purge summary: %v", out)
	}

	var userCount, msgCount, settingsCount, whitelistCount, logCount int64
	db.Model(&User{}).Where("id = ?", userID).Count(&userCount)
	db.Model(&Message{}).Where("sender_id = ?", userID).Count(&msgCount)
	db.Model(&TwinSettings{}).Where("user_id = ?", userID).Count(&settingsCount)
	db.Model(&WhitelistRule{}).Where("user_id = ?", userID).Count(&whitelistCount)
	db.Model(&EscalationLog{}).Where("user_id = ?", userID).Count(&logCount)
	if userCount != 0 || msgCount != 0 || settingsCount != 0 || whitelistCount != 0 || logCount != 0 {
		t.Fatalf("expected all user-linked rows purged, got user=%d msg=%d settings=%d whitelist=%d log=%d",
			userCount, msgCount, settingsCount, whitelistCount, logCount)
	}

	req2, _ := http.NewRequest(http.MethodDelete, server.URL+"/users/"+strconv.FormatUint(uint64(userID), 10), nil)
	resp2, err := http.DefaultClient.Do(req2)
	if err != nil {
		t.Fatalf("second delete request: %v", err)
	}
	if resp2.StatusCode != http.StatusNotFound {
		t.Fatalf("expected 404 on repeat delete, got %d", resp2.StatusCode)
	}
}

func TestPeerVetoBlocksTwinAutoSendEvenAtL2WithWhitelistMatch(t *testing.T) {
	server, db := setupTestServer(t)

	senderID := mustSignup(t, server.URL, "지민")
	setAutonomyLevel(t, server.URL, senderID, AutonomyL2)
	db.Create(&WhitelistRule{UserID: senderID, TopicKeyword: "저녁"})

	conv := Conversation{IsGroup: false}
	if err := db.Create(&conv).Error; err != nil {
		t.Fatalf("create conversation: %v", err)
	}
	convBase := server.URL + "/conversations/" + strconv.FormatUint(uint64(conv.ID), 10)

	vetoResp := postJSON(t, convBase+"/veto", nil)
	if vetoResp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 triggering veto, got %d", vetoResp.StatusCode)
	}

	// Would otherwise auto-send (L2 + whitelist match + approved), but the
	// veto must override every other check.
	resp := postJSON(t, convBase+"/messages", sendMessageRequest{
		SenderID: senderID, Text: "저녁 뭐 먹었어?", SenderMode: SenderTwin, Approved: true,
	})
	if resp.StatusCode != http.StatusForbidden {
		t.Fatalf("expected 403: peer veto must override L2 whitelist + approval, got %d", resp.StatusCode)
	}

	var count int64
	db.Model(&Message{}).Where("conversation_id = ?", conv.ID).Count(&count)
	if count != 0 {
		t.Fatalf("no twin message should be sent after veto, found %d rows", count)
	}
}

func TestPeerVetoDoesNotBlockHumanMessages(t *testing.T) {
	server, db := setupTestServer(t)

	senderID := mustSignup(t, server.URL, "다은")

	conv := Conversation{IsGroup: false}
	if err := db.Create(&conv).Error; err != nil {
		t.Fatalf("create conversation: %v", err)
	}
	convBase := server.URL + "/conversations/" + strconv.FormatUint(uint64(conv.ID), 10)

	postJSON(t, convBase+"/veto", nil)

	resp := postJSON(t, convBase+"/messages", sendMessageRequest{SenderID: senderID, Text: "안녕", SenderMode: SenderHuman})
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("veto must not block the human's own messages, got %d", resp.StatusCode)
	}
}

func TestVetoMissingConversation(t *testing.T) {
	server, _ := setupTestServer(t)
	resp := postJSON(t, server.URL+"/conversations/9999/veto", nil)
	if resp.StatusCode != http.StatusNotFound {
		t.Fatalf("expected 404, got %d", resp.StatusCode)
	}
}

func TestAdminMetricsCountsMessagesEscalationsAndVeto(t *testing.T) {
	server, db := setupTestServer(t)

	senderID := mustSignup(t, server.URL, "메트릭")
	setAutonomyLevel(t, server.URL, senderID, AutonomyL1)

	conv := Conversation{IsGroup: false}
	if err := db.Create(&conv).Error; err != nil {
		t.Fatalf("create conversation: %v", err)
	}
	convBase := server.URL + "/conversations/" + strconv.FormatUint(uint64(conv.ID), 10)

	postJSON(t, convBase+"/messages", sendMessageRequest{SenderID: senderID, Text: "안녕", SenderMode: SenderHuman})
	postJSON(t, convBase+"/messages", sendMessageRequest{SenderID: senderID, Text: "ㅇㅇ", SenderMode: SenderTwin, Approved: true})
	postJSON(t, convBase+"/messages", sendMessageRequest{SenderID: senderID, Text: "계좌번호 알려줄게", SenderMode: SenderTwin})

	conv2 := Conversation{IsGroup: false}
	db.Create(&conv2)
	postJSON(t, server.URL+"/conversations/"+strconv.FormatUint(uint64(conv2.ID), 10)+"/veto", nil)

	resp, err := http.Get(server.URL + "/admin/metrics")
	if err != nil {
		t.Fatalf("get metrics: %v", err)
	}
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d", resp.StatusCode)
	}
	var out map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&out)

	if out["messages_human_total"].(float64) != 1 {
		t.Fatalf("expected 1 human message, got %v", out["messages_human_total"])
	}
	if out["messages_twin_total"].(float64) != 1 {
		t.Fatalf("expected 1 twin message, got %v", out["messages_twin_total"])
	}
	if out["escalations_total"].(float64) != 1 {
		t.Fatalf("expected 1 escalation, got %v", out["escalations_total"])
	}
	byReason := out["escalations_by_reason"].(map[string]interface{})
	if byReason["금전"].(float64) != 1 {
		t.Fatalf("expected 1 금전 escalation, got %v", byReason)
	}
	if out["conversations_total"].(float64) != 2 || out["conversations_vetoed"].(float64) != 1 {
		t.Fatalf("expected 2 conversations, 1 vetoed, got %v", out)
	}
	if out["peer_veto_rate"].(float64) != 0.5 {
		t.Fatalf("expected 0.5 veto rate, got %v", out["peer_veto_rate"])
	}
	if out["invites_minted"].(float64) < 1 || out["invites_used"].(float64) < 1 {
		t.Fatalf("expected at least 1 minted/used invite, got %v", out)
	}
}

func TestWhitelistRuleCRUD(t *testing.T) {
	server, _ := setupTestServer(t)
	userID := mustSignup(t, server.URL, "화이트")
	base := server.URL + "/users/" + strconv.FormatUint(uint64(userID), 10) + "/whitelist-rules"

	createResp := postJSON(t, base, createWhitelistRuleRequest{TopicKeyword: "저녁"})
	if createResp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 creating rule, got %d", createResp.StatusCode)
	}
	var created map[string]interface{}
	json.NewDecoder(createResp.Body).Decode(&created)
	if created["topic_keyword"] != "저녁" || created["contact_id"] != nil {
		t.Fatalf("unexpected created rule: %v", created)
	}
	ruleID := uint(created["id"].(float64))

	listResp, err := http.Get(base)
	if err != nil {
		t.Fatalf("list rules: %v", err)
	}
	var list map[string]interface{}
	json.NewDecoder(listResp.Body).Decode(&list)
	rules := list["whitelist_rules"].([]interface{})
	if len(rules) != 1 {
		t.Fatalf("expected 1 rule listed, got %d", len(rules))
	}

	delReq, _ := http.NewRequest(http.MethodDelete, base+"/"+strconv.FormatUint(uint64(ruleID), 10), nil)
	delResp, err := http.DefaultClient.Do(delReq)
	if err != nil {
		t.Fatalf("delete rule: %v", err)
	}
	if delResp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 deleting rule, got %d", delResp.StatusCode)
	}

	listResp2, _ := http.Get(base)
	var list2 map[string]interface{}
	json.NewDecoder(listResp2.Body).Decode(&list2)
	if len(list2["whitelist_rules"].([]interface{})) != 0 {
		t.Fatalf("expected 0 rules after delete, got %v", list2)
	}

	delAgain, _ := http.NewRequest(http.MethodDelete, base+"/"+strconv.FormatUint(uint64(ruleID), 10), nil)
	delAgainResp, _ := http.DefaultClient.Do(delAgain)
	if delAgainResp.StatusCode != http.StatusNotFound {
		t.Fatalf("expected 404 deleting an already-deleted rule, got %d", delAgainResp.StatusCode)
	}
}

func TestWhitelistRuleCRUDMissingUser(t *testing.T) {
	server, _ := setupTestServer(t)
	resp := postJSON(t, server.URL+"/users/9999/whitelist-rules", createWhitelistRuleRequest{TopicKeyword: "저녁"})
	if resp.StatusCode != http.StatusNotFound {
		t.Fatalf("expected 404, got %d", resp.StatusCode)
	}
}

func TestRetractTwinMessage(t *testing.T) {
	server, db := setupTestServer(t)
	senderID := mustSignup(t, server.URL, "되돌리기")
	setAutonomyLevel(t, server.URL, senderID, AutonomyL2)
	db.Create(&WhitelistRule{UserID: senderID, TopicKeyword: "저녁"})

	conv := Conversation{IsGroup: false}
	if err := db.Create(&conv).Error; err != nil {
		t.Fatalf("create conversation: %v", err)
	}
	convBase := server.URL + "/conversations/" + strconv.FormatUint(uint64(conv.ID), 10)

	wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "/ws/conversations/" +
		strconv.FormatUint(uint64(conv.ID), 10)
	ws, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("dial ws: %v", err)
	}
	defer ws.Close()

	sendResp := postJSON(t, convBase+"/messages", sendMessageRequest{SenderID: senderID, Text: "저녁 뭐 먹었어?", SenderMode: SenderTwin})
	if sendResp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 auto-sending, got %d", sendResp.StatusCode)
	}
	var sent map[string]interface{}
	json.NewDecoder(sendResp.Body).Decode(&sent)
	msgID := uint(sent["id"].(float64))

	var sendBroadcast map[string]interface{}
	if err := ws.ReadJSON(&sendBroadcast); err != nil {
		t.Fatalf("read send broadcast: %v", err)
	}
	if sendBroadcast["type"] != "message" {
		t.Fatalf("expected type:message on send broadcast, got %v", sendBroadcast)
	}

	retractResp := postJSON(t, server.URL+"/messages/"+strconv.FormatUint(uint64(msgID), 10)+"/retract", nil)
	if retractResp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 retracting, got %d", retractResp.StatusCode)
	}

	var retractBroadcast map[string]interface{}
	if err := ws.ReadJSON(&retractBroadcast); err != nil {
		t.Fatalf("read retract broadcast: %v", err)
	}
	if retractBroadcast["type"] != "retraction" || uint(retractBroadcast["id"].(float64)) != msgID {
		t.Fatalf("unexpected retraction broadcast: %v", retractBroadcast)
	}

	var message Message
	db.First(&message, msgID)
	if !message.Retracted {
		t.Fatalf("expected message.Retracted true after retract")
	}

	// Already retracted -- must not succeed again.
	again := postJSON(t, server.URL+"/messages/"+strconv.FormatUint(uint64(msgID), 10)+"/retract", nil)
	if again.StatusCode != http.StatusConflict {
		t.Fatalf("expected 409 retracting an already-retracted message, got %d", again.StatusCode)
	}
}

func TestRetractRejectsHumanMessage(t *testing.T) {
	server, db := setupTestServer(t)
	senderID := mustSignup(t, server.URL, "사람")

	conv := Conversation{IsGroup: false}
	if err := db.Create(&conv).Error; err != nil {
		t.Fatalf("create conversation: %v", err)
	}
	sendResp := postJSON(t, server.URL+"/conversations/"+strconv.FormatUint(uint64(conv.ID), 10)+"/messages", sendMessageRequest{
		SenderID: senderID, Text: "안녕", SenderMode: SenderHuman,
	})
	var sent map[string]interface{}
	json.NewDecoder(sendResp.Body).Decode(&sent)
	msgID := uint(sent["id"].(float64))

	resp := postJSON(t, server.URL+"/messages/"+strconv.FormatUint(uint64(msgID), 10)+"/retract", nil)
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("expected 400 retracting a human message, got %d", resp.StatusCode)
	}
}

func TestRetractMissingMessage(t *testing.T) {
	server, _ := setupTestServer(t)
	resp := postJSON(t, server.URL+"/messages/9999/retract", nil)
	if resp.StatusCode != http.StatusNotFound {
		t.Fatalf("expected 404, got %d", resp.StatusCode)
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

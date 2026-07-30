package main

import (
	"encoding/json"
	"net/http"
	"testing"
	"time"
)

func TestMintInviteWithNoteExpiryAndRevoke(t *testing.T) {
	server, _ := setupTestServer(t)

	resp := postJSONAuth(t, server.URL+"/invites", "test-admin-token", mintInvitesRequest{
		Note:          "e2e-friend",
		ExpiresInDays: 7,
		Count:         1,
	})
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("mint: %d", resp.StatusCode)
	}
	var one map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&one)
	code, _ := one["code"].(string)
	if code == "" || one["note"] != "e2e-friend" || one["status"] != "unused" {
		t.Fatalf("unexpected mint payload %v", one)
	}
	if one["expires_at"] == nil {
		t.Fatalf("expected expires_at, got %v", one)
	}

	batch := postJSONAuth(t, server.URL+"/invites", "test-admin-token", mintInvitesRequest{
		Note:  "batch",
		Count: 3,
	})
	if batch.StatusCode != http.StatusOK {
		t.Fatalf("batch: %d", batch.StatusCode)
	}
	var bout map[string]interface{}
	json.NewDecoder(batch.Body).Decode(&bout)
	if len(bout["invites"].([]interface{})) != 3 {
		t.Fatalf("expected 3 invites, got %v", bout)
	}

	listReq, _ := http.NewRequest(http.MethodGet, server.URL+"/invites", nil)
	listReq.Header.Set("Authorization", "Bearer test-admin-token")
	listResp, err := http.DefaultClient.Do(listReq)
	if err != nil {
		t.Fatal(err)
	}
	if listResp.StatusCode != http.StatusOK {
		t.Fatalf("list: %d", listResp.StatusCode)
	}

	rev := postJSONAuth(t, server.URL+"/invites/"+code+"/revoke", "test-admin-token", nil)
	if rev.StatusCode != http.StatusOK {
		t.Fatalf("revoke: %d", rev.StatusCode)
	}
	var revOut map[string]interface{}
	json.NewDecoder(rev.Body).Decode(&revOut)
	if revOut["status"] != "revoked" {
		t.Fatalf("expected revoked, got %v", revOut)
	}

	signup := postJSON(t, server.URL+"/auth/signup", signupRequest{InviteCode: code, DisplayName: "X"})
	if signup.StatusCode != http.StatusBadRequest {
		t.Fatalf("expected 400 for revoked invite, got %d", signup.StatusCode)
	}
}

func TestExpiredInviteRejected(t *testing.T) {
	server, db := setupTestServer(t)
	code := mintInvite(t, server.URL)
	past := time.Now().Add(-time.Hour)
	db.Model(&InviteCode{}).Where("code = ?", code).Update("expires_at", past)

	signup := postJSON(t, server.URL+"/auth/signup", signupRequest{InviteCode: code, DisplayName: "Late"})
	if signup.StatusCode != http.StatusBadRequest {
		t.Fatalf("expected 400 for expired invite, got %d", signup.StatusCode)
	}
}

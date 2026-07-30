package main

import (
	"encoding/json"
	"io"
	"net/http"
	"testing"
)

func TestDemoInviteReusableForMultipleSignups(t *testing.T) {
	t.Setenv("ALLOW_DEMO_INVITE", "1")
	server, db := setupTestServer(t)
	seedDemoInvite(db)

	demoResp, err := http.Get(server.URL + "/demo")
	if err != nil {
		t.Fatalf("GET /demo: %v", err)
	}
	defer demoResp.Body.Close()
	var demo map[string]any
	if err := json.NewDecoder(demoResp.Body).Decode(&demo); err != nil {
		t.Fatalf("decode demo: %v", err)
	}
	if demo["demo_invite_code"] != demoInviteCode {
		t.Fatalf("demo code: %v", demo["demo_invite_code"])
	}

	a := postJSON(t, server.URL+"/auth/signup", signupRequest{
		InviteCode:  demoInviteCode,
		DisplayName: "테스터A",
	})
	defer a.Body.Close()
	aBody, _ := io.ReadAll(a.Body)
	if a.StatusCode != http.StatusOK {
		t.Fatalf("first demo signup: %d %s", a.StatusCode, aBody)
	}

	b := postJSON(t, server.URL+"/auth/signup", signupRequest{
		InviteCode:  demoInviteCode,
		DisplayName: "테스터B",
	})
	defer b.Body.Close()
	bBody, _ := io.ReadAll(b.Body)
	if b.StatusCode != http.StatusOK {
		t.Fatalf("second demo signup should reuse code: %d %s", b.StatusCode, bBody)
	}

	var outA, outB map[string]any
	_ = json.Unmarshal(aBody, &outA)
	_ = json.Unmarshal(bBody, &outB)
	if outA["id"] == outB["id"] {
		t.Fatalf("expected distinct users, got %#v %#v", outA, outB)
	}
}

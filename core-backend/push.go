package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
	"gorm.io/gorm"
)

const fcmMessagingScope = "https://www.googleapis.com/auth/firebase.messaging"

// FCM_SERVER_KEY = legacy HTTP API (often disabled in new Firebase projects).
// Prefer FCM HTTP v1 via service account:
//   FCM_SERVICE_ACCOUNT_FILE=/path/to.json
//   or FCM_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
func fcmServerKey() string {
	return strings.TrimSpace(os.Getenv("FCM_SERVER_KEY"))
}

func loadFCMServiceAccountJSON() ([]byte, error) {
	if path := strings.TrimSpace(os.Getenv("FCM_SERVICE_ACCOUNT_FILE")); path != "" {
		b, err := os.ReadFile(path)
		if err != nil {
			return nil, fmt.Errorf("read FCM_SERVICE_ACCOUNT_FILE: %w", err)
		}
		return bytes.TrimSpace(b), nil
	}
	if raw := strings.TrimSpace(os.Getenv("FCM_SERVICE_ACCOUNT_JSON")); raw != "" {
		return []byte(raw), nil
	}
	return nil, nil
}

type fcmServiceAccount struct {
	ProjectID string `json:"project_id"`
}

type fcmLegacyPayload struct {
	To           string            `json:"to,omitempty"`
	Registration []string          `json:"registration_ids,omitempty"`
	Priority     string            `json:"priority"`
	Notification map[string]string `json:"notification"`
	Data         map[string]string `json:"data,omitempty"`
}

type fcmV1MessageRequest struct {
	Message fcmV1Message `json:"message"`
}

type fcmV1Message struct {
	Token        string            `json:"token"`
	Notification map[string]string `json:"notification,omitempty"`
	Data         map[string]string `json:"data,omitempty"`
}

var (
	fcmTokenMu     sync.Mutex
	fcmTokenSource oauth2.TokenSource
	fcmProjectID   string
)

func fcmV1Ready(ctx context.Context) (projectID string, ts oauth2.TokenSource, err error) {
	fcmTokenMu.Lock()
	defer fcmTokenMu.Unlock()
	if fcmTokenSource != nil && fcmProjectID != "" {
		return fcmProjectID, fcmTokenSource, nil
	}
	raw, err := loadFCMServiceAccountJSON()
	if err != nil {
		return "", nil, err
	}
	if len(raw) == 0 {
		return "", nil, nil
	}
	var sa fcmServiceAccount
	if err := json.Unmarshal(raw, &sa); err != nil {
		return "", nil, fmt.Errorf("parse service account json: %w", err)
	}
	if strings.TrimSpace(sa.ProjectID) == "" {
		return "", nil, fmt.Errorf("service account json missing project_id")
	}
	creds, err := google.CredentialsFromJSON(ctx, raw, fcmMessagingScope)
	if err != nil {
		return "", nil, fmt.Errorf("fcm credentials: %w", err)
	}
	fcmProjectID = sa.ProjectID
	fcmTokenSource = creds.TokenSource
	return fcmProjectID, fcmTokenSource, nil
}

func collectFCMRegistrationIDs(tokens []DeviceToken) []string {
	regIDs := make([]string, 0, len(tokens))
	for _, t := range tokens {
		if strings.HasPrefix(t.Token, "install:") {
			continue
		}
		regIDs = append(regIDs, t.Token)
	}
	return regIDs
}

func notifyUser(db *gorm.DB, userID uint, title, body string, data map[string]string) (sent int, skippedReason string, err error) {
	var tokens []DeviceToken
	db.Where("user_id = ?", userID).Find(&tokens)
	if len(tokens) == 0 {
		return 0, "no_device_tokens", nil
	}

	regIDs := collectFCMRegistrationIDs(tokens)
	if len(regIDs) == 0 {
		runtimeMetrics.recordPush(0, true)
		return 0, "only_placeholder_tokens", nil
	}

	ctx, cancel := context.WithTimeout(context.Background(), 12*time.Second)
	defer cancel()

	projectID, ts, v1err := fcmV1Ready(ctx)
	if v1err != nil {
		runtimeMetrics.recordPush(0, true)
		return 0, "", v1err
	}
	if projectID != "" && ts != nil {
		n, err := sendFCMv1(ctx, projectID, ts, regIDs, title, body, data)
		if err != nil {
			runtimeMetrics.recordPush(0, true)
			return 0, "", err
		}
		runtimeMetrics.recordPush(n, false)
		return n, "", nil
	}

	// Legacy fallback when service account is not configured.
	key := fcmServerKey()
	if key == "" {
		runtimeMetrics.recordPush(0, true)
		return 0, "fcm_not_configured", nil
	}
	n, err := sendFCMLegacy(key, regIDs, title, body, data)
	if err != nil {
		runtimeMetrics.recordPush(0, true)
		return 0, "", err
	}
	runtimeMetrics.recordPush(n, false)
	return n, "", nil
}

func sendFCMv1(ctx context.Context, projectID string, ts oauth2.TokenSource, regIDs []string, title, body string, data map[string]string) (int, error) {
	tok, err := ts.Token()
	if err != nil {
		return 0, fmt.Errorf("fcm access token: %w", err)
	}
	client := &http.Client{Timeout: 10 * time.Second}
	url := fmt.Sprintf("https://fcm.googleapis.com/v1/projects/%s/messages:send", projectID)
	sent := 0
	var lastErr error
	for _, reg := range regIDs {
		payload := fcmV1MessageRequest{
			Message: fcmV1Message{
				Token:        reg,
				Notification: map[string]string{"title": title, "body": body},
				Data:         data,
			},
		}
		raw, _ := json.Marshal(payload)
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(raw))
		if err != nil {
			return sent, err
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+tok.AccessToken)
		resp, err := client.Do(req)
		if err != nil {
			lastErr = err
			continue
		}
		respBody, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		resp.Body.Close()
		if resp.StatusCode >= 300 {
			lastErr = fmt.Errorf("fcm v1 returned %d: %s", resp.StatusCode, strings.TrimSpace(string(respBody)))
			continue
		}
		sent++
	}
	if sent == 0 && lastErr != nil {
		return 0, lastErr
	}
	return sent, nil
}

func sendFCMLegacy(key string, regIDs []string, title, body string, data map[string]string) (int, error) {
	payload := fcmLegacyPayload{
		Registration: regIDs,
		Priority:     "high",
		Notification: map[string]string{"title": title, "body": body},
		Data:         data,
	}
	raw, _ := json.Marshal(payload)
	req, err := http.NewRequest(http.MethodPost, "https://fcm.googleapis.com/fcm/send", bytes.NewReader(raw))
	if err != nil {
		return 0, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "key="+key)

	client := &http.Client{Timeout: 8 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		return 0, fmt.Errorf("fcm returned %d", resp.StatusCode)
	}
	return len(regIDs), nil
}

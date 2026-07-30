package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strings"
	"time"

	"gorm.io/gorm"
)

// FCM legacy HTTP API (server key). When FCM_SERVER_KEY is unset, notifyUser
// records a metric and returns without error so product flows stay usable.
func fcmServerKey() string {
	return strings.TrimSpace(os.Getenv("FCM_SERVER_KEY"))
}

type fcmLegacyPayload struct {
	To           string                 `json:"to,omitempty"`
	Registration []string               `json:"registration_ids,omitempty"`
	Priority     string                 `json:"priority"`
	Notification map[string]string      `json:"notification"`
	Data         map[string]string      `json:"data,omitempty"`
}

func notifyUser(db *gorm.DB, userID uint, title, body string, data map[string]string) (sent int, skippedReason string, err error) {
	var tokens []DeviceToken
	db.Where("user_id = ?", userID).Find(&tokens)
	if len(tokens) == 0 {
		return 0, "no_device_tokens", nil
	}

	key := fcmServerKey()
	if key == "" {
		runtimeMetrics.recordPush(0, true)
		return 0, "fcm_not_configured", nil
	}

	// Skip placeholder install:* tokens — they are not real FCM registration IDs.
	regIDs := make([]string, 0, len(tokens))
	for _, t := range tokens {
		if strings.HasPrefix(t.Token, "install:") {
			continue
		}
		regIDs = append(regIDs, t.Token)
	}
	if len(regIDs) == 0 {
		runtimeMetrics.recordPush(0, true)
		return 0, "only_placeholder_tokens", nil
	}

	payload := fcmLegacyPayload{
		Registration: regIDs,
		Priority:     "high",
		Notification: map[string]string{"title": title, "body": body},
		Data:         data,
	}
	raw, _ := json.Marshal(payload)
	req, err := http.NewRequest(http.MethodPost, "https://fcm.googleapis.com/fcm/send", bytes.NewReader(raw))
	if err != nil {
		return 0, "", err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "key="+key)

	client := &http.Client{Timeout: 8 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		runtimeMetrics.recordPush(0, true)
		return 0, "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		runtimeMetrics.recordPush(0, true)
		return 0, "", fmt.Errorf("fcm returned %d", resp.StatusCode)
	}
	runtimeMetrics.recordPush(len(regIDs), false)
	return len(regIDs), "", nil
}

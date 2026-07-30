package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
)

// AIServiceClient calls the Python AI service's POST /draft (ai-service/,
// tech-design.md §8's "Go 코어 → Python AI 서비스, 내부망 HTTP").
type AIServiceClient struct {
	BaseURL string
	HTTP    *http.Client
}

func newAIServiceClient() *AIServiceClient {
	return &AIServiceClient{BaseURL: aiServiceURL(), HTTP: http.DefaultClient}
}

type draftRequest struct {
	ContextLines  []string `json:"context_lines"`
	StyleExamples []string `json:"style_examples,omitempty"`
	History       []string `json:"history,omitempty"`
	K             int      `json:"k,omitempty"`
}

type draftResponse struct {
	Status string `json:"status"`
	Text   string `json:"text"`
}

func (c *AIServiceClient) requestDraft(req draftRequest) (*draftResponse, error) {
	body, err := json.Marshal(req)
	if err != nil {
		return nil, err
	}

	resp, err := c.HTTP.Post(c.BaseURL+"/draft", "application/json", bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("ai service unreachable: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("ai service returned %d", resp.StatusCode)
	}

	var out draftResponse
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return nil, err
	}
	return &out, nil
}

type escalationCheckRequest struct {
	Text string `json:"text"`
}

type escalationCheckResponse struct {
	Escalate bool   `json:"escalate"`
	Reason   string `json:"reason"`
}

// checkEscalation calls ai-service's POST /escalate/check -- the hard gate
// that any twin-authored (auto-sent) message must pass, independent of
// whether a draft was generated through this client. Callers must fail
// closed (treat an error here as "escalate") per AGENTS.md's fail-safe
// invariant: uncertainty must never resolve to an unattended send.
func (c *AIServiceClient) checkEscalation(text string) (*escalationCheckResponse, error) {
	body, err := json.Marshal(escalationCheckRequest{Text: text})
	if err != nil {
		return nil, err
	}

	resp, err := c.HTTP.Post(c.BaseURL+"/escalate/check", "application/json", bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("ai service unreachable: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("ai service returned %d", resp.StatusCode)
	}

	var out escalationCheckResponse
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return nil, err
	}
	return &out, nil
}

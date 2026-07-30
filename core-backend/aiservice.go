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

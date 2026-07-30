package main

import (
	"sync"
	"time"
)

// RuntimeMetrics tracks draft-generation latency and AI error rates in process
// memory (roadmap B). Survives for the life of the process; not a substitute
// for a time-series DB, but enough for a minimal admin dashboard.
type RuntimeMetrics struct {
	mu sync.Mutex

	DraftRequests    int64
	DraftErrors      int64
	DraftLatencies   []time.Duration // capped ring of recent samples
	EscalateChecks   int64
	EscalateErrors   int64
	TwinSendsBlocked int64
	PushAttempts     int64
	PushSkipped      int64
	PushDelivered    int64
}

const maxLatencySamples = 200

var runtimeMetrics = &RuntimeMetrics{}

func (m *RuntimeMetrics) recordDraft(latency time.Duration, err error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.DraftRequests++
	if err != nil {
		m.DraftErrors++
	}
	m.DraftLatencies = append(m.DraftLatencies, latency)
	if len(m.DraftLatencies) > maxLatencySamples {
		m.DraftLatencies = m.DraftLatencies[len(m.DraftLatencies)-maxLatencySamples:]
	}
}

func (m *RuntimeMetrics) recordEscalate(err error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.EscalateChecks++
	if err != nil {
		m.EscalateErrors++
	}
}

func (m *RuntimeMetrics) recordTwinBlocked() {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.TwinSendsBlocked++
}

func (m *RuntimeMetrics) recordPush(delivered int, skipped bool) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.PushAttempts++
	if skipped {
		m.PushSkipped++
	}
	m.PushDelivered += int64(delivered)
}

func (m *RuntimeMetrics) snapshot() ginHMetrics {
	m.mu.Lock()
	defer m.mu.Unlock()

	var sum time.Duration
	var max time.Duration
	for _, d := range m.DraftLatencies {
		sum += d
		if d > max {
			max = d
		}
	}
	var avgMs float64
	if n := len(m.DraftLatencies); n > 0 {
		avgMs = float64(sum.Milliseconds()) / float64(n)
	}
	var errRate float64
	if m.DraftRequests > 0 {
		errRate = float64(m.DraftErrors) / float64(m.DraftRequests)
	}
	var escErrRate float64
	if m.EscalateChecks > 0 {
		escErrRate = float64(m.EscalateErrors) / float64(m.EscalateChecks)
	}
	return ginHMetrics{
		DraftRequests:       m.DraftRequests,
		DraftErrors:         m.DraftErrors,
		DraftErrorRate:      errRate,
		DraftLatencyAvgMs:   avgMs,
		DraftLatencyMaxMs:   float64(max.Milliseconds()),
		DraftLatencySamples: len(m.DraftLatencies),
		EscalateChecks:      m.EscalateChecks,
		EscalateErrors:      m.EscalateErrors,
		EscalateErrorRate:   escErrRate,
		TwinSendsBlocked:    m.TwinSendsBlocked,
		PushAttempts:        m.PushAttempts,
		PushSkipped:         m.PushSkipped,
		PushDelivered:       m.PushDelivered,
	}
}

type ginHMetrics struct {
	DraftRequests       int64
	DraftErrors         int64
	DraftErrorRate      float64
	DraftLatencyAvgMs   float64
	DraftLatencyMaxMs   float64
	DraftLatencySamples int
	EscalateChecks      int64
	EscalateErrors      int64
	EscalateErrorRate   float64
	TwinSendsBlocked    int64
	PushAttempts        int64
	PushSkipped         int64
	PushDelivered       int64
}

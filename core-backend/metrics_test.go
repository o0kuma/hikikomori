package main

import "testing"

// TestRecordTwinBlockedByReason confirms recordTwinBlocked attributes counts
// to the right reason key and still keeps a top-line total in sync, so
// existing dashboards/scripts reading twin_sends_blocked keep working
// alongside the new by-reason breakdown.
func TestRecordTwinBlockedByReason(t *testing.T) {
	m := &RuntimeMetrics{}
	m.recordTwinBlocked("x")
	m.recordTwinBlocked("x")
	m.recordTwinBlocked("y")

	snap := m.snapshot()
	if snap.TwinSendsBlocked != 3 {
		t.Fatalf("expected top-line total 3, got %d", snap.TwinSendsBlocked)
	}
	if got := snap.TwinSendsBlockedByReason["x"]; got != 2 {
		t.Fatalf(`expected TwinSendsBlockedByReason["x"] == 2, got %d`, got)
	}
	if got := snap.TwinSendsBlockedByReason["y"]; got != 1 {
		t.Fatalf(`expected TwinSendsBlockedByReason["y"] == 1, got %d`, got)
	}
	if len(snap.TwinSendsBlockedByReason) != 2 {
		t.Fatalf("expected exactly 2 distinct reasons, got %v", snap.TwinSendsBlockedByReason)
	}
}

// TestRecordTwinBlockedSnapshotIsolation confirms the snapshot's map is a
// copy, not an alias into the live struct -- so a caller mutating the
// returned map (e.g. JSON-encoding it, or a test asserting on it) can't
// corrupt runtimeMetrics's internal state.
func TestRecordTwinBlockedSnapshotIsolation(t *testing.T) {
	m := &RuntimeMetrics{}
	m.recordTwinBlocked("peer_veto")

	snap := m.snapshot()
	snap.TwinSendsBlockedByReason["peer_veto"] = 999

	again := m.snapshot()
	if again.TwinSendsBlockedByReason["peer_veto"] != 1 {
		t.Fatalf("snapshot map leaked a live reference into RuntimeMetrics, got %v", again.TwinSendsBlockedByReason)
	}
}

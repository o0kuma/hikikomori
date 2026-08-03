package main

import "time"

type SenderMode string

const (
	SenderHuman SenderMode = "human"
	SenderTwin  SenderMode = "twin"
)

type AutonomyLevel string

const (
	AutonomyL0 AutonomyLevel = "L0"
	AutonomyL1 AutonomyLevel = "L1"
	AutonomyL2 AutonomyLevel = "L2"
)

func validAutonomyLevel(l AutonomyLevel) bool {
	return l == AutonomyL0 || l == AutonomyL1 || l == AutonomyL2
}

// RelationshipTier is the minimum-2-tier persona split roadmap.md §2.7-B /
// PRD.md §2.1-②/§3.1 requires: draft tone should read differently for a
// close friend than for someone you'd stay formal with. Defaults to the
// more conservative "formal" tier for anyone who hasn't set this explicitly
// (same fail-safe-leaning default philosophy as AutonomyLevel defaulting
// to L0 when missing).
type RelationshipTier string

const (
	RelationshipClose  RelationshipTier = "close"
	RelationshipFormal RelationshipTier = "formal"
)

func validRelationshipTier(t RelationshipTier) bool {
	return t == RelationshipClose || t == RelationshipFormal
}

type User struct {
	ID          uint   `gorm:"primaryKey"`
	InviteCode  string `gorm:"uniqueIndex;not null"`
	DisplayName string `gorm:"not null"`
	CreatedAt   time.Time
}

// Session is a bearer token issued at signup/login (roadmap A2).
// v1 beta: opaque random token, no refresh rotation yet.
type Session struct {
	ID        uint   `gorm:"primaryKey"`
	Token     string `gorm:"uniqueIndex;not null"`
	UserID    uint   `gorm:"not null;index"`
	CreatedAt time.Time
	ExpiresAt time.Time `gorm:"not null;index"`
}

// InviteCode is a pre-minted, single-use code (roadmap.md Phase 1 §2.6
// "초대 기반 베타 가입 플로우") -- signup validates against this table instead
// of just deduping User.InviteCode, so joining actually requires a code
// someone handed out, not any never-used string.
type InviteCode struct {
	ID           uint   `gorm:"primaryKey"`
	Code         string `gorm:"uniqueIndex;not null"`
	Note         string // operator memo (recipient/channel) — roadmap C invite ops
	CreatedAt    time.Time
	ExpiresAt    *time.Time
	RevokedAt    *time.Time
	UsedAt       *time.Time
	UsedByUserID *uint
}

type Contact struct {
	ID               uint `gorm:"primaryKey"`
	OwnerUserID      uint `gorm:"not null;index"`
	ContactUserID    *uint
	DisplayName      string `gorm:"not null"`
	RelationshipNote string
	// RelationshipTier overrides the owner's global TwinSettings.RelationshipTier
	// for drafts sent to this specific contact (roadmap.md §2.7-B). Nil means
	// "use the global default".
	RelationshipTier *RelationshipTier
	// AutonomyLevel overrides the owner's global TwinSettings.AutonomyLevel
	// for auto-send gating in 1:1 conversations with this specific contact
	// (roadmap.md §2.7-D, PRD.md §3.1 "전역 기본값 + 상대별 예외 설정"). Nil
	// means "use the global default". Same nullable-override shape as
	// RelationshipTier above.
	AutonomyLevel *AutonomyLevel
	CreatedAt     time.Time
}

// TwinDisabledByPeer is the veto flag (tech-design.md §4: "대화방 단위
// 플래그(twin_disabled_by_peer)") -- per conversation, not per contact, so
// it lives here rather than on Contact. Set by POST /conversations/:id/veto
// when the counterpart asks to talk to the human only; checked before any
// twin auto-send in that conversation (main.go).
// TwinDisabledByFlood is the flood/spam auto-pause flag (roadmap.md §2.7-C,
// PRD.md §4 "스팸 감지 임계치 초과 시 응대 중단"). Unlike TwinDisabledByPeer
// (a deliberate one-way human/peer choice, no un-veto endpoint by design),
// this is a fully automatic system action, so AGENTS.md's "every automatic
// action needs post-hoc notification + one-tap undo" applies -- it's
// reversible via POST /conversations/:id/flood-reset, unlike peer veto.
type Conversation struct {
	ID                  uint `gorm:"primaryKey"`
	IsGroup             bool `gorm:"not null;default:false"`
	TwinDisabledByPeer  bool `gorm:"not null;default:false"`
	TwinDisabledByFlood bool `gorm:"not null;default:false"`
	CreatedAt           time.Time
}

type ConversationParticipant struct {
	ID             uint `gorm:"primaryKey"`
	ConversationID uint `gorm:"not null;index"`
	UserID         uint `gorm:"not null;index"`
	// LastReadMessageID is this participant's read marker (roadmap.md
	// §2.7-A "단톡 따라잡기") -- nil means nothing read yet. Drives the
	// unread badge and GET /conversations/:id/summary's "안 본 동안" window.
	LastReadMessageID *uint
}

type Message struct {
	ID             uint       `gorm:"primaryKey"`
	ConversationID uint       `gorm:"not null;index"`
	SenderID       uint       `gorm:"not null"`
	SenderMode     SenderMode `gorm:"not null;default:human"`
	Text           string     `gorm:"not null"`
	// Retracted is the one-tap undo for an L2 auto-send (PRD.md §3.1,
	// AGENTS.md "every automatic action needs post-hoc notification +
	// one-tap undo") -- set via POST /messages/:id/retract, twin-authored
	// messages only.
	Retracted bool `gorm:"not null;default:false"`
	// DraftEdited is the implicit L1-approval-rate signal (PRD.md §5's
	// "초안을 수정 없이 그대로 발송한 비율", vision.md's naturalness metric,
	// deploy-checklist.md N4-12). Nil for human-authored messages and for
	// any message not sent through the draft-approval flow (old rows, or a
	// client that didn't send original_draft_text) -- only set to a
	// concrete true/false for twin-mode messages where the client told us
	// what the original AI draft text was, so we could diff it against
	// what actually got sent. Never guessed.
	DraftEdited *bool
	// NaturalnessRating is the explicit "이 답장 나답아요?" signal (vision.md
	// naturalness metric, PRD.md §5, deploy-checklist.md N4-12): true = 👍,
	// false = 👎, nil = not rated yet. Set via POST /messages/:id/feedback,
	// twin-authored messages only (rating a human's own words doesn't make
	// sense for this metric).
	NaturalnessRating *bool
	CreatedAt         time.Time
}

type TwinSettings struct {
	ID               uint             `gorm:"primaryKey"`
	UserID           uint             `gorm:"uniqueIndex;not null"`
	AutonomyLevel    AutonomyLevel    `gorm:"not null;default:L0"`
	RelationshipTier RelationshipTier `gorm:"not null;default:formal"`
	CreatedAt        time.Time
	UpdatedAt        time.Time
}

// WhitelistRule is the L2 auto-send whitelist -- a (contact, topic) pair the
// owner has approved for unattended replies. ContactID nil = any counterpart
// (PRD.md §3.1).
type WhitelistRule struct {
	ID           uint `gorm:"primaryKey"`
	UserID       uint `gorm:"not null;index"`
	ContactID    *uint
	TopicKeyword string `gorm:"not null"`
	CreatedAt    time.Time
}

// EscalationLog is one row per escalation_filter trigger -- the post-hoc
// notification + undo trail required by AGENTS.md's absolute safety
// invariants.
type EscalationLog struct {
	ID             uint   `gorm:"primaryKey"`
	UserID         uint   `gorm:"not null;index"`
	ConversationID uint   `gorm:"not null;index"`
	Reason         string `gorm:"not null"`
	MessageSnippet string `gorm:"not null"`
	Resolved       bool   `gorm:"not null;default:false"`
	CreatedAt      time.Time
}

// DeviceToken stores an FCM registration token for push (roadmap B).
// Sending pushes is wired later; v1 persists tokens per user/device.
type DeviceToken struct {
	ID        uint   `gorm:"primaryKey"`
	UserID    uint   `gorm:"not null;index"`
	Token     string `gorm:"uniqueIndex;not null"`
	Platform  string `gorm:"not null;default:android"`
	CreatedAt time.Time
	UpdatedAt time.Time
}

var allModels = []interface{}{
	&User{},
	&Session{},
	&InviteCode{},
	&Contact{},
	&Conversation{},
	&ConversationParticipant{},
	&Message{},
	&TwinSettings{},
	&WhitelistRule{},
	&EscalationLog{},
	&DeviceToken{},
}

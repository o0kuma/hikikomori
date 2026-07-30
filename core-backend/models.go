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

type User struct {
	ID          uint   `gorm:"primaryKey"`
	InviteCode  string `gorm:"uniqueIndex;not null"`
	DisplayName string `gorm:"not null"`
	CreatedAt   time.Time
}

// InviteCode is a pre-minted, single-use code (roadmap.md Phase 1 §2.6
// "초대 기반 베타 가입 플로우") -- signup validates against this table instead
// of just deduping User.InviteCode, so joining actually requires a code
// someone handed out, not any never-used string.
type InviteCode struct {
	ID           uint   `gorm:"primaryKey"`
	Code         string `gorm:"uniqueIndex;not null"`
	CreatedAt    time.Time
	UsedAt       *time.Time
	UsedByUserID *uint
}

type Contact struct {
	ID               uint `gorm:"primaryKey"`
	OwnerUserID      uint `gorm:"not null;index"`
	ContactUserID    *uint
	DisplayName      string `gorm:"not null"`
	RelationshipNote string
	CreatedAt        time.Time
}

// TwinDisabledByPeer is the veto flag (tech-design.md §4: "대화방 단위
// 플래그(twin_disabled_by_peer)") -- per conversation, not per contact, so
// it lives here rather than on Contact. Set by POST /conversations/:id/veto
// when the counterpart asks to talk to the human only; checked before any
// twin auto-send in that conversation (main.go).
type Conversation struct {
	ID                 uint `gorm:"primaryKey"`
	IsGroup            bool `gorm:"not null;default:false"`
	TwinDisabledByPeer bool `gorm:"not null;default:false"`
	CreatedAt          time.Time
}

type ConversationParticipant struct {
	ID             uint `gorm:"primaryKey"`
	ConversationID uint `gorm:"not null;index"`
	UserID         uint `gorm:"not null;index"`
}

type Message struct {
	ID             uint       `gorm:"primaryKey"`
	ConversationID uint       `gorm:"not null;index"`
	SenderID       uint       `gorm:"not null"`
	SenderMode     SenderMode `gorm:"not null;default:human"`
	Text           string     `gorm:"not null"`
	CreatedAt      time.Time
}

type TwinSettings struct {
	ID            uint          `gorm:"primaryKey"`
	UserID        uint          `gorm:"uniqueIndex;not null"`
	AutonomyLevel AutonomyLevel `gorm:"not null;default:L0"`
	CreatedAt     time.Time
	UpdatedAt     time.Time
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

var allModels = []interface{}{
	&User{},
	&InviteCode{},
	&Contact{},
	&Conversation{},
	&ConversationParticipant{},
	&Message{},
	&TwinSettings{},
	&WhitelistRule{},
	&EscalationLog{},
}

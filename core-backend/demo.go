package main

import (
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// Shared closed-beta demo invite shown on the Flutter signup screen.
// Multiple testers can use the same code when ALLOW_DEMO_INVITE is enabled.
const demoInviteCode = "DEMO-YKAVU"

func demoInviteEnabled() bool {
	v := strings.TrimSpace(os.Getenv("ALLOW_DEMO_INVITE"))
	if v == "" {
		// Default on for local / Phase-1 shared testing. Set ALLOW_DEMO_INVITE=0 in prod.
		return true
	}
	switch strings.ToLower(v) {
	case "0", "false", "no", "off":
		return false
	default:
		return true
	}
}

func isDemoInviteCode(code string) bool {
	return strings.EqualFold(strings.TrimSpace(code), demoInviteCode)
}

func seedDemoInvite(db *gorm.DB) {
	if !demoInviteEnabled() {
		return
	}
	var existing InviteCode
	err := db.Where("code = ?", demoInviteCode).First(&existing).Error
	if err == nil {
		return
	}
	if err != gorm.ErrRecordNotFound {
		log.Printf("demo invite lookup: %v", err)
		return
	}
	inv := InviteCode{
		Code: demoInviteCode,
		Note: "shared demo invite (ALLOW_DEMO_INVITE)",
	}
	if err := db.Create(&inv).Error; err != nil {
		log.Printf("demo invite seed failed: %v", err)
		return
	}
	log.Printf("seeded demo invite code %s", demoInviteCode)
}

func registerDemoRoutes(r *gin.Engine) {
	r.GET("/demo", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"demo_invite_enabled": demoInviteEnabled(),
			"demo_invite_code":    demoInviteCode,
			"demo_display_name":   "테스터",
			"hint":                "회원가입 화면에 표시된 테스트 코드를 그대로 쓰면 됩니다.",
			"pairing_steps": []string{
				"두 명이 같은 DEMO-YKAVU 코드로 각각 가입한다 (시크릿/다른 브라우저).",
				"각자 대화 목록의 내 사용자 ID를 복사해 상대에게 알려 준다.",
				"연락처에 상대 표시 이름 + 숫자 ID를 넣고 추가한 뒤 「대화」를 누른다.",
				"메시지를 보내고, 자율성 L1에서 와카뷰 초안을 한 번 승인·전송해 본다.",
				"L0(비서)에서는 초안을 「입력창으로 옮기기」만 되며 — 직접 보낸다.",
			},
			"notes": []string{
				"대화는 표시 이름이 아니라 숫자 사용자 ID로 연결됩니다.",
				"ID 없는 옛 연락처는 연락처 화면에서 「ID 입력」으로 고치면 됩니다.",
			},
		})
	})
}

// demoSignupInviteCode returns the InviteCode row for demo signups, creating it
// if needed. Usability checks for "already used" are skipped by the caller.
func demoSignupInviteCode(db *gorm.DB) (InviteCode, error) {
	var invite InviteCode
	err := db.Where("code = ?", demoInviteCode).First(&invite).Error
	if err == nil {
		return invite, nil
	}
	if err != gorm.ErrRecordNotFound {
		return InviteCode{}, err
	}
	seedDemoInvite(db)
	err = db.Where("code = ?", demoInviteCode).First(&invite).Error
	return invite, err
}

// uniqueDemoUserInvite stores a per-user value on users.invite_code (unique)
// while still accepting the shared DEMO-YKAVU input.
func uniqueDemoUserInvite() (string, error) {
	suffix, err := generateInviteCode()
	if err != nil {
		return "", err
	}
	return demoInviteCode + "-" + suffix, nil
}

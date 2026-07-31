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

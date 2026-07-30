package main

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type mintInvitesRequest struct {
	Note          string `json:"note"`
	ExpiresInDays int    `json:"expires_in_days"` // 0 → default 14; <0 → no expiry
	Count         int    `json:"count"`           // default 1, max 20
}

func inviteStatus(inv InviteCode, now time.Time) string {
	if inv.RevokedAt != nil {
		return "revoked"
	}
	if inv.UsedAt != nil {
		return "used"
	}
	if inv.ExpiresAt != nil && !inv.ExpiresAt.After(now) {
		return "expired"
	}
	return "unused"
}

func inviteUsable(inv InviteCode, now time.Time) (ok bool, detail string) {
	switch inviteStatus(inv, now) {
	case "unused":
		return true, ""
	case "used":
		return false, "invite code already used"
	case "revoked":
		return false, "invite code revoked"
	case "expired":
		return false, "invite code expired"
	default:
		return false, "invite code not usable"
	}
}

func inviteJSON(inv InviteCode, now time.Time) gin.H {
	out := gin.H{
		"code":       inv.Code,
		"note":       inv.Note,
		"status":     inviteStatus(inv, now),
		"created_at": inv.CreatedAt,
	}
	if inv.ExpiresAt != nil {
		out["expires_at"] = inv.ExpiresAt
	}
	if inv.RevokedAt != nil {
		out["revoked_at"] = inv.RevokedAt
	}
	if inv.UsedAt != nil {
		out["used_at"] = inv.UsedAt
		out["used_by_user_id"] = inv.UsedByUserID
	}
	return out
}

func registerInviteOpsRoutes(r *gin.Engine, db *gorm.DB) {
	r.POST("/invites", func(c *gin.Context) {
		if !requireAdmin(c) {
			return
		}
		var req mintInvitesRequest
		_ = c.ShouldBindJSON(&req) // body optional for backward compat
		count := req.Count
		if count <= 0 {
			count = 1
		}
		if count > 20 {
			c.JSON(http.StatusBadRequest, gin.H{"detail": "count must be <= 20"})
			return
		}
		expiresIn := req.ExpiresInDays
		if expiresIn == 0 {
			expiresIn = 14
		}

		now := time.Now()
		codes := make([]gin.H, 0, count)
		for i := 0; i < count; i++ {
			code, err := generateInviteCode()
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"detail": err.Error()})
				return
			}
			invite := InviteCode{Code: code, Note: req.Note}
			if expiresIn > 0 {
				exp := now.Add(time.Duration(expiresIn) * 24 * time.Hour)
				invite.ExpiresAt = &exp
			}
			if err := db.Create(&invite).Error; err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"detail": err.Error()})
				return
			}
			codes = append(codes, inviteJSON(invite, now))
		}
		if count == 1 {
			c.JSON(http.StatusOK, codes[0])
			return
		}
		c.JSON(http.StatusOK, gin.H{"invites": codes})
	})

	r.GET("/invites", func(c *gin.Context) {
		if !requireAdmin(c) {
			return
		}
		var invites []InviteCode
		db.Order("id desc").Limit(200).Find(&invites)
		now := time.Now()
		out := make([]gin.H, 0, len(invites))
		for _, inv := range invites {
			out = append(out, inviteJSON(inv, now))
		}
		c.JSON(http.StatusOK, gin.H{"invites": out})
	})

	r.POST("/invites/:code/revoke", func(c *gin.Context) {
		if !requireAdmin(c) {
			return
		}
		code := c.Param("code")
		var invite InviteCode
		if err := db.Where("code = ?", code).First(&invite).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"detail": "invite not found"})
			return
		}
		if invite.UsedAt != nil {
			c.JSON(http.StatusConflict, gin.H{"detail": "cannot revoke a used invite"})
			return
		}
		if invite.RevokedAt != nil {
			c.JSON(http.StatusOK, inviteJSON(invite, time.Now()))
			return
		}
		now := time.Now()
		invite.RevokedAt = &now
		db.Save(&invite)
		c.JSON(http.StatusOK, inviteJSON(invite, now))
	})
}

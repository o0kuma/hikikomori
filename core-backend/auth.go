package main

import (
	"crypto/rand"
	"encoding/hex"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

const sessionTTL = 30 * 24 * time.Hour

func adminAPIToken() string {
	return os.Getenv("ADMIN_API_TOKEN")
}

func bearerToken(c *gin.Context) string {
	h := c.GetHeader("Authorization")
	if h == "" {
		return ""
	}
	parts := strings.SplitN(h, " ", 2)
	if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
		return ""
	}
	return strings.TrimSpace(parts[1])
}

func requireAdmin(c *gin.Context) bool {
	expected := adminAPIToken()
	if expected == "" {
		c.JSON(http.StatusServiceUnavailable, gin.H{
			"detail": "ADMIN_API_TOKEN is not configured; refusing privileged endpoint",
		})
		return false
	}
	if bearerToken(c) != expected {
		c.JSON(http.StatusUnauthorized, gin.H{"detail": "admin authorization required"})
		return false
	}
	return true
}

func createSession(db *gorm.DB, userID uint) (Session, error) {
	buf := make([]byte, 24)
	if _, err := rand.Read(buf); err != nil {
		return Session{}, err
	}
	session := Session{
		Token:     hex.EncodeToString(buf),
		UserID:    userID,
		ExpiresAt: time.Now().Add(sessionTTL),
	}
	if err := db.Create(&session).Error; err != nil {
		return Session{}, err
	}
	return session, nil
}

// currentUser resolves Authorization: Bearer <session token> to a User.
// Returns false after writing an error response when required is true.
func currentUser(c *gin.Context, db *gorm.DB, required bool) (User, bool) {
	token := bearerToken(c)
	if token == "" {
		if required {
			c.JSON(http.StatusUnauthorized, gin.H{"detail": "Authorization Bearer token required"})
		}
		return User{}, false
	}
	var session Session
	if err := db.Where("token = ?", token).First(&session).Error; err != nil {
		if required {
			c.JSON(http.StatusUnauthorized, gin.H{"detail": "invalid session token"})
		}
		return User{}, false
	}
	if time.Now().After(session.ExpiresAt) {
		if required {
			c.JSON(http.StatusUnauthorized, gin.H{"detail": "session expired"})
		}
		return User{}, false
	}
	var user User
	if err := db.First(&user, session.UserID).Error; err != nil {
		if required {
			c.JSON(http.StatusUnauthorized, gin.H{"detail": "session user not found"})
		}
		return User{}, false
	}
	return user, true
}

func requireSelf(c *gin.Context, db *gorm.DB, pathUserID uint) bool {
	user, ok := currentUser(c, db, true)
	if !ok {
		return false
	}
	if user.ID != pathUserID {
		c.JSON(http.StatusForbidden, gin.H{"detail": "token user does not match path user id"})
		return false
	}
	return true
}

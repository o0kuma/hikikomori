package main

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
	"gorm.io/gorm"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

type signupRequest struct {
	InviteCode  string `json:"invite_code" binding:"required"`
	DisplayName string `json:"display_name" binding:"required"`
}

type sendMessageRequest struct {
	SenderID   uint       `json:"sender_id" binding:"required"`
	Text       string     `json:"text" binding:"required"`
	SenderMode SenderMode `json:"sender_mode"`
}

func setupRouter(db *gorm.DB, relay *ConnectionManager) *gin.Engine {
	r := gin.Default()

	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	r.POST("/auth/signup", func(c *gin.Context) {
		var req signupRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"detail": err.Error()})
			return
		}

		var existing User
		if err := db.Where("invite_code = ?", req.InviteCode).First(&existing).Error; err == nil {
			c.JSON(http.StatusConflict, gin.H{"detail": "invite_code already used"})
			return
		}

		user := User{InviteCode: req.InviteCode, DisplayName: req.DisplayName}
		if err := db.Create(&user).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"detail": err.Error()})
			return
		}
		db.Create(&TwinSettings{UserID: user.ID, AutonomyLevel: AutonomyL0})

		c.JSON(http.StatusOK, gin.H{"id": user.ID, "display_name": user.DisplayName})
	})

	r.POST("/conversations/:id/messages", func(c *gin.Context) {
		convID, ok := parseUintParam(c, "id")
		if !ok {
			return
		}

		var conversation Conversation
		if err := db.First(&conversation, convID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"detail": "conversation not found"})
			return
		}

		var req sendMessageRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"detail": err.Error()})
			return
		}
		if req.SenderMode == "" {
			req.SenderMode = SenderHuman
		}

		message := Message{
			ConversationID: convID,
			SenderID:       req.SenderID,
			SenderMode:     req.SenderMode,
			Text:           req.Text,
		}
		if err := db.Create(&message).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"detail": err.Error()})
			return
		}

		relay.broadcast(convID, gin.H{
			"id":          message.ID,
			"sender_id":   message.SenderID,
			"sender_mode": message.SenderMode,
			"text":        message.Text,
		})

		c.JSON(http.StatusOK, gin.H{"id": message.ID})
	})

	r.GET("/ws/conversations/:id", func(c *gin.Context) {
		convID, ok := parseUintParam(c, "id")
		if !ok {
			return
		}

		conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
		if err != nil {
			return
		}
		defer conn.Close()

		relay.add(convID, conn)
		defer relay.remove(convID, conn)

		for {
			if _, _, err := conn.ReadMessage(); err != nil {
				break
			}
		}
	})

	return r
}

func parseUintParam(c *gin.Context, name string) (uint, bool) {
	id, err := strconv.ParseUint(c.Param(name), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"detail": name + " must be a positive integer"})
		return 0, false
	}
	return uint(id), true
}

func main() {
	db := openDB()
	relay := newConnectionManager()
	r := setupRouter(db, relay)
	r.Run(":8080")
}

package main

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type registerDeviceRequest struct {
	Token    string `json:"token" binding:"required"`
	Platform string `json:"platform"`
}

func messageJSON(m Message) gin.H {
	return gin.H{
		"id":              m.ID,
		"conversation_id": m.ConversationID,
		"sender_id":       m.SenderID,
		"sender_mode":     m.SenderMode,
		"text":            m.Text,
		"retracted":       m.Retracted,
		"created_at":      m.CreatedAt,
	}
}

func registerBRoutes(r *gin.Engine, db *gorm.DB) {
	// Minimal HTML dashboard for operators (roadmap B). JSON stays on /admin/metrics.
	r.GET("/admin/dashboard", func(c *gin.Context) {
		if !requireAdmin(c) {
			return
		}
		c.Header("Content-Type", "text/html; charset=utf-8")
		c.String(http.StatusOK, adminDashboardHTML)
	})

	r.POST("/users/:id/device-tokens", func(c *gin.Context) {
		userID, ok := parseUintParam(c, "id")
		if !ok {
			return
		}
		if !requireSelf(c, db, userID) {
			return
		}
		var req registerDeviceRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"detail": err.Error()})
			return
		}
		platform := req.Platform
		if platform == "" {
			platform = "android"
		}
		var existing DeviceToken
		err := db.Where("token = ?", req.Token).First(&existing).Error
		if err == nil {
			existing.UserID = userID
			existing.Platform = platform
			existing.UpdatedAt = time.Now()
			db.Save(&existing)
			c.JSON(http.StatusOK, gin.H{"id": existing.ID, "token": existing.Token, "platform": existing.Platform})
			return
		}
		row := DeviceToken{UserID: userID, Token: req.Token, Platform: platform}
		if err := db.Create(&row).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"detail": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{"id": row.ID, "token": row.Token, "platform": row.Platform})
	})

	r.GET("/users/:id/device-tokens", func(c *gin.Context) {
		userID, ok := parseUintParam(c, "id")
		if !ok {
			return
		}
		if !requireSelf(c, db, userID) {
			return
		}
		var tokens []DeviceToken
		db.Where("user_id = ?", userID).Order("id desc").Find(&tokens)
		out := make([]gin.H, 0, len(tokens))
		for _, t := range tokens {
			out = append(out, gin.H{
				"id":         t.ID,
				"platform":   t.Platform,
				"token_tail": trimToken(t.Token),
				"updated_at": t.UpdatedAt,
			})
		}
		c.JSON(http.StatusOK, gin.H{"device_tokens": out})
	})

	// Multi-device awareness: list active sessions for the authenticated user.
	r.GET("/users/:id/sessions", func(c *gin.Context) {
		userID, ok := parseUintParam(c, "id")
		if !ok {
			return
		}
		actor, ok := currentUser(c, db, true)
		if !ok {
			return
		}
		if actor.ID != userID {
			c.JSON(http.StatusForbidden, gin.H{"detail": "can only list your own sessions"})
			return
		}
		var sessions []Session
		db.Where("user_id = ? AND expires_at > ?", userID, time.Now()).Order("id desc").Find(&sessions)
		out := make([]gin.H, 0, len(sessions))
		current := bearerToken(c)
		for _, s := range sessions {
			out = append(out, gin.H{
				"id":         s.ID,
				"created_at": s.CreatedAt,
				"expires_at": s.ExpiresAt,
				"is_current": s.Token == current,
			})
		}
		c.JSON(http.StatusOK, gin.H{"sessions": out})
	})
}

func trimToken(token string) string {
	if len(token) <= 8 {
		return "****"
	}
	return "…" + token[len(token)-6:]
}

const adminDashboardHTML = `<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>분신 · admin metrics</title>
  <style>
    :root { font-family: ui-sans-serif, system-ui, sans-serif; color: #14231e; background: #f3f7f5; }
    body { margin: 0; padding: 24px; }
    h1 { margin: 0 0 8px; font-size: 1.4rem; }
    p { color: #40554c; margin: 0 0 20px; }
    .grid { display: grid; gap: 12px; grid-template-columns: repeat(auto-fill, minmax(180px, 1fr)); }
    .card { background: #fff; border: 1px solid #d5e2db; border-radius: 10px; padding: 14px; }
    .k { font-size: .75rem; color: #5b7267; text-transform: uppercase; letter-spacing: .04em; }
    .v { font-size: 1.4rem; font-weight: 700; margin-top: 4px; }
    pre { background: #fff; border: 1px solid #d5e2db; border-radius: 10px; padding: 14px; overflow: auto; }
    button { margin: 12px 0; padding: 8px 14px; border-radius: 8px; border: 0; background: #1f6f5b; color: #fff; cursor: pointer; }
  </style>
</head>
<body>
  <h1>분신 운영 지표</h1>
  <p>Bearer ADMIN_API_TOKEN 으로 /admin/metrics 를 불러옵니다. 생성 지연·오류율은 프로세스 메모리 샘플입니다.</p>
  <button onclick="load()">새로고침</button>
  <div class="grid" id="cards"></div>
  <h2 style="margin-top:28px;font-size:1rem">raw JSON</h2>
  <pre id="raw">loading…</pre>
  <script>
    async function load() {
      const params = new URLSearchParams(location.search);
      let token = params.get('token') || localStorage.ADMIN_API_TOKEN || '';
      if (!token) {
        token = prompt('ADMIN_API_TOKEN') || '';
        if (token) localStorage.ADMIN_API_TOKEN = token;
      } else if (params.get('token')) {
        localStorage.ADMIN_API_TOKEN = token;
      }
      const r = await fetch('/admin/metrics', { headers: token ? { 'Authorization': 'Bearer ' + token } : {} });
      const data = await r.json();
      document.getElementById('raw').textContent = JSON.stringify(data, null, 2);
      const cards = [
        ['users', data.users_total],
        ['human msgs', data.messages_human_total],
        ['twin msgs', data.messages_twin_total],
        ['escalations', data.escalations_total],
        ['peer veto rate', (data.peer_veto_rate || 0).toFixed(3)],
        ['draft req', data.draft_requests],
        ['draft err rate', (data.draft_error_rate || 0).toFixed(3)],
        ['draft avg ms', (data.draft_latency_avg_ms || 0).toFixed(1)],
        ['draft max ms', (data.draft_latency_max_ms || 0).toFixed(1)],
        ['escalate err rate', (data.escalate_error_rate || 0).toFixed(3)],
      ];
      document.getElementById('cards').innerHTML = cards.map(([k,v]) =>
        '<div class="card"><div class="k">'+k+'</div><div class="v">'+v+'</div></div>').join('');
    }
    load();
  </script>
</body>
</html>
`
# Docker 배포 (N2-B) — `msn.iykyka.com`

체크리스트: [`deploy-checklist.md`](./deploy-checklist.md) N2-B.
결정: N2-A (Postgres, AI 내부망, Web 우선, 시크릿 env, `ALLOW_DEMO_INVITE=1`).

## 구성

| 서비스 | 역할 | 호스트 노출 |
|--------|------|-------------|
| `postgres` | PostgreSQL 16 | 아니오 (볼륨 `ykavu_pgdata`) |
| `ai-service` | FastAPI draft/escalate | 아니오 |
| `core-backend` | Go API + WS | 아니오 (web nginx가 프록시) |
| `web` | Flutter web + nginx | `WEB_HOST_PORT`→80 (기본 8088) |

엣지(Caddy/Traefik/기존 프록시)는 **`web:80`만** `https://msn.iykyka.com`에 연결하면 된다.

## 로컬 / 서버

```bash
cp .env.example .env
# 최소: ADMIN_API_TOKEN, POSTGRES_PASSWORD, (선택) GEMINI_API_KEY
# 로컬 스모크:
#   PUBLIC_API_BASE=http://localhost:8088

docker compose up -d --build
curl -sS http://localhost:8088/health
curl -sS http://localhost:8088/demo
```

Portainer·OpenResty 컷오버 상세: [`deploy-portainer.md`](./deploy-portainer.md).
서버 원샷: `./scripts/server-up.sh`

## 시크릿

- git에 `.env` 커밋 금지 (`AGENTS.md` / N2-A5)
- Portainer/호스트에 `ADMIN_API_TOKEN`, `POSTGRES_PASSWORD`, `GEMINI_API_KEY` 설정

## 컷오버 메모 (N2-B11)

1. 새 스택을 임시 포트 또는 스테이징로 Up → 스모크
2. 기존 Node MSN 중지
3. 리버스 프록시를 `web:80`으로 전환
4. 롤백: 프록시를 구 MSN으로 되돌리고 스택 stop

## 검증 메모 (2026-07-31)

- `docker compose build` : `ai-service`, `core-backend` 이미지 빌드 OK
- `mobile/Dockerfile.prebuilt` + `nginx -t` OK (API upstream 지연 해석)
- 일부 샌드박스/에이전트 VM에서는 Docker **bridge 네트워크 TCP가 막혀**
  컨테이너 간 `postgres:5432` 연결이 타임아웃될 수 있음. **Portainer가 돌아가는
  실제 호스트에서는 기본 bridge compose를 사용**하면 된다.
- Flutter multi-stage (`mobile/Dockerfile`)는 이미지 용량이 크므로 Portainer 빌드
  시 시간 여유를 둔다. 급하면 호스트에서 `flutter build web` 후 `Dockerfile.prebuilt`.

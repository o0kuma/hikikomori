# Portainer 배포 · 컷오버 (N2-B8~B12)

대상: `https://msn.iykyka.com`  
스택 정의: 저장소 root [`docker-compose.yml`](../docker-compose.yml)  
개요: [`deploy-docker.md`](./deploy-docker.md)

## 라이브 상태 (2026-07-31 컷오버 완료)

| URL | 결과 |
|-----|------|
| `https://msn.iykyka.com/health` | `{"status":"ok"}` — 와카뷰 |
| `https://msn.iykyka.com/demo` | `DEMO-YKAVU` |
| `https://msn.iykyka.com/` | Flutter web 200 |
| 서버 path | `~/project/ykavu` (`docker compose`) |
| web host port | `8788` (NPM이 `ykavu-web-1:80`으로 프록시) |
| 구 MSN | `iykyk_msn-service` **stopped** (롤백 시 start) |
| 엣지 | Nginx Proxy Manager (`nginx-proxy-app-1`, openresty) |

`docker-compose.yml`의 `web` 서비스는 external network `nginx-proxy_default`에 연결됨.

---

## A. Portainer 스택 생성

1. Portainer → **Stacks** → **Add stack**
2. Build method: **Repository** (권장)
   - Repository URL: `https://gitea.iykyka.com/oh/iykyka.git` (또는 GitHub `o0kuma/hikikomori`)
   - Compose path: `docker-compose.yml`
   - Branch: `main`
3. **Environment variables** (시크릿 — git 금지):

| Name | 예 |
|------|-----|
| `ADMIN_API_TOKEN` | 긴 랜덤 |
| `POSTGRES_PASSWORD` | 긴 랜덤 |
| `POSTGRES_USER` | `ykavu` |
| `POSTGRES_DB` | `ykavu` |
| `GEMINI_API_KEY` | (있으면) |
| `ALLOW_DEMO_INVITE` | `1` |
| `PUBLIC_API_BASE` | `https://msn.iykyka.com` |
| `WEB_HOST_PORT` | `8088` (컷오버 전 임시) → 전환 후 openresty가 가리키는 포트에 맞춤 |
| `FCM_SERVER_KEY` | (없으면 비움) |

4. Deploy the stack → 빌드 완료까지 대기 (Flutter multi-stage는 수 분~십수 분)
5. 호스트에서 확인:

```bash
curl -sS http://127.0.0.1:8088/health   # → {"status":"ok"}
curl -sS http://127.0.0.1:8088/demo    # → DEMO-YKAVU
```

### SSH로 올릴 때

```bash
git clone https://gitea.iykyka.com/oh/iykyka.git ykavu && cd ykavu
cp .env.example .env   # 값 채움
./scripts/server-up.sh
```

---

## B. OpenResty 컷오버 (N2-B11)

1. **병렬 기동**: 새 스택을 `WEB_HOST_PORT=8088`(또는 빈 포트)로 Up, 구 MSN은 유지
2. 로컬 스모크: `/health` → `status`, `/demo` → `DEMO-YKAVU`, 브라우저로 `http://HOST:8088/` 가입
3. OpenResty upstream을 **구 Express → `127.0.0.1:8088`(web)** 로 변경 후 reload
4. 공개 URL 스모크:
   - `https://msn.iykyka.com/health` → `{"status":"ok"}`
   - `https://msn.iykyka.com/demo` → demo JSON
   - 회원가입 `DEMO-YKAVU`
5. 구 Node MSN 컨테이너/프로세스 중지
6. **롤백**: upstream을 구 MSN으로 되돌리고 openresty reload

WebSocket: openresty에서 `/ws` 에 `Upgrade` / `Connection` 헤더 전달 필요
(nginx `proxy_set_header Upgrade $http_upgrade` 와 동일).

---

## C. 배포 스모크 체크 (N2-B12)

- [ ] `GET /health` → `{"status":"ok"}`
- [ ] `GET /demo` → `demo_invite_code=DEMO-YKAVU`
- [ ] 브라우저 가입 → 말투 온보딩 → 대화 목록
- [ ] (가능 시) draft/L1 1회
- [ ] AI·Postgres 호스트 포트 미노출 확인

---

## Master에게 필요한 것 (에이전트 대행 시)

아래 중 **하나**만 있으면 N2-B8~B12를 에이전트가 이어서 실행할 수 있다.

1. SSH: `iykyka@iykyka.com:7788` 용 **private key** (또는 일시 비밀번호 — 채팅 대신 시크릿 채널 권장)
2. Portainer **API access token** + endpoint id
3. Master가 A~C를 직접 수행한 뒤 결과만 공유

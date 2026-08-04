# hikikomori / 와카뷰 (Ykavu)

카카오톡 대안 메신저 — "나를 대신해 남과 대화하는 AI 와카뷰".

## 구조

| 경로 | 역할 |
|---|---|
| `docs/` | 기획·PRD·기술설계·로드맵·배포 체크리스트·PoC |
| `core-backend/` | Go 코어 (가입·메시지·WebSocket·자율성·안전장치) |
| `ai-service/` | Python AI 내부 API (`/draft`, `/escalate/check`) |
| `backend/` | 초기 Python 프로토타입 (참고용) |
| `poc/tone-corpus/` | PoC 실험 스크립트 |
| `mobile/` | Flutter 클라이언트 (Android 우선 · Web 배포) |
| `secrets/` | FCM 등 시크릿 마운트용 (git에 실파일 커밋 금지) |

## 문서 지도

권위 순서·에이전트 규칙: [`AGENTS.md`](./AGENTS.md) · [`CLAUDE.md`](./CLAUDE.md).

### 기획 · 결정

| 문서 | 용도 |
|------|------|
| [`docs/PLANNING.md`](./docs/PLANNING.md) | 프로세스·산출물 가이드 |
| [`docs/decision-log.md`](./docs/decision-log.md) | Q1~**Q8 확정**, **Q9 제안** (단일 결정 기준) |
| [`docs/vision.md`](./docs/vision.md) | 문제·가치제안·성공 지표 |
| [`docs/PRD.md`](./docs/PRD.md) | P0 기능·유저 플로우 |
| [`docs/tech-design.md`](./docs/tech-design.md) | 온디바이스/서버 경계·자율성 엔진 |
| [`docs/risk-log.md`](./docs/risk-log.md) | 리스크·완화 추적 |
| [`docs/account-settings-ia.md`](./docs/account-settings-ia.md) | 계정·로그인·설정 IA (Q8) · L2 의미 갭 (Q9) |

### 실행 · 잔여 작업 (여기가 본체)

| 문서 | 용도 |
|------|------|
| [`docs/roadmap.md`](./docs/roadmap.md) | Phase 체크리스트 (`[x]` / `[~]` / `[ ]`) |
| [`docs/deploy-checklist.md`](./docs/deploy-checklist.md) | **배포·잔여 실행 트랙** (DONE/NOW/NEXT · Track A~C · N1~N5 · N4-W) |
| [`docs/web-upgrade.md`](./docs/web-upgrade.md) | **웹 고도화** (데모/프리뷰 · W0~W7 · Web Push · PWA). Q9 비범위 |

남은 일: 웹은 `web-upgrade.md` / `deploy-checklist` §N4-W. Android/FCM 실기기·APK·SHARE_URL·PoC는 §N4·§N5.

### 배포 · 운영

| 문서 | 용도 |
|------|------|
| [`docs/deploy-docker.md`](./docs/deploy-docker.md) | Compose·이미지 |
| [`docs/deploy-portainer.md`](./docs/deploy-portainer.md) | Portainer·컷오버 |
| [`docs/ops-backup.md`](./docs/ops-backup.md) | 백업 |
| [`docs/invite-ops.md`](./docs/invite-ops.md) | 초대 코드 운영 |
| [`docs/fcm-setup.md`](./docs/fcm-setup.md) | FCM Android N4-1~4 · Web Push는 `web-upgrade` W4 |
| [`docs/android-release.md`](./docs/android-release.md) | 내부 release APK 서명 |
| [`docs/tester-guide.md`](./docs/tester-guide.md) | 테스터 안내 · `DEMO-YKAVU` |

### PoC · 회의

| 문서 | 용도 |
|------|------|
| [`docs/poc-plan.md`](./docs/poc-plan.md) | PoC #1/#3 실행 계획 |
| [`docs/poc-materials.md`](./docs/poc-materials.md) | 모집·역할극 자료 |
| [`docs/user-interview-guide.md`](./docs/user-interview-guide.md) | Q3 자율성 인터뷰 |
| [`docs/prototype.md`](./docs/prototype.md) | 클릭 프로토타입 앵커 · `SHARE_URL` (Master 기입) |
| [`docs/meeting-review-summary.md`](./docs/meeting-review-summary.md) | 회의 1페이지 요약 |

## AI 에이전트 규칙

- [`AGENTS.md`](./AGENTS.md) · [`CLAUDE.md`](./CLAUDE.md)
- **브랜치:** 작업·머지는 항상 `main`
- **리모트:** GitHub `origin` + Gitea `gitea`(iykyka) — `main` 갱신 후 `./scripts/push-both.sh`
- **Q9** (L2 수신 트리거 자동응대)는 Master 확정 전 구현 금지

## 현재 단계

- Phase 1 **A~C** + Track A/B/C + **Q8**(로그인·설정·로그아웃) 코드 완료
- 라이브: [`https://msn.iykyka.com`](https://msn.iykyka.com) · 데모 코드 **`DEMO-YKAVU`**
- **진행 중 (설계 완료·구현 Wi 승인 대기):** 웹 고도화 [`docs/web-upgrade.md`](./docs/web-upgrade.md) (W0 경계 done · W1~W7 todo)
- **후순위 (Master):** Android N4 — `google-services.json` · 실기기 FCM · UI 탭 · APK · `SHARE_URL`
- **결정 대기:** Q9 — L2 의미 (카피 정렬 ± 수신 자동응대) — 웹 트랙에도 **비범위**
- **맨 마지막:** N5 / D — 사람 PoC. §3 기본값 추측 금지

상세 현황: [`docs/deploy-checklist.md`](./docs/deploy-checklist.md) §0.

## 로컬 실행 (요약)

```bash
# 터미널 1 — AI 서비스
cd ai-service && pip install -r requirements.txt
export GEMINI_API_KEY=...   # or repo-root .env
uvicorn app.main:app --port 8001

# 터미널 2 — 코어 백엔드
cd core-backend
export ADMIN_API_TOKEN=dev-admin-token
go run . migrate && go run .

# 초대 코드 발급 예:
# curl -X POST http://localhost:8080/invites -H "Authorization: Bearer $ADMIN_API_TOKEN"

# 터미널 3 — Flutter (Android)
cd mobile && flutter run --dart-define=CORE_API_BASE=http://10.0.2.2:8080
```

## Docker (N2-B / `msn.iykyka.com`)

- 구성: [`docs/deploy-docker.md`](./docs/deploy-docker.md)
- Portainer·컷오버: [`docs/deploy-portainer.md`](./docs/deploy-portainer.md)
- FCM: [`docs/fcm-setup.md`](./docs/fcm-setup.md)
- 서버 기동: `./scripts/server-up.sh` (호스트에서 `.env` 채운 뒤)

```bash
cp .env.example .env   # ADMIN_API_TOKEN, POSTGRES_PASSWORD 필수
# 로컬: PUBLIC_API_BASE=http://localhost:8088
docker compose up -d --build
curl -sS http://localhost:8088/health
```

Postgres·AI는 내부망만. 엣지 프록시는 `web:80`(또는 `WEB_HOST_PORT`)만 공개.

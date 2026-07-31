# hikikomori / 와카뷰 (가칭)

카카오톡 대안 메신저 — "나를 대신해 남과 대화하는 AI 와카뷰".

## 구조

| 경로 | 역할 |
|---|---|
| `docs/` | 기획·PRD·기술설계·로드맵·PoC 계획 |
| `core-backend/` | Go 코어 (가입·메시지·WebSocket·자율성·안전장치) |
| `ai-service/` | Python AI 내부 API (`/draft`, `/escalate/check`) |
| `backend/` | 초기 Python 프로토타입 (참고용) |
| `poc/tone-corpus/` | PoC 실험 스크립트 |
| `mobile/` | Flutter 클라이언트 (Android 우선) |

## 문서

- 기획: [`docs/PLANNING.md`](./docs/PLANNING.md) · 결정: [`docs/decision-log.md`](./docs/decision-log.md) (Q1~Q7 **확정**)
- Vision / PRD / 기술설계: [`docs/vision.md`](./docs/vision.md) · [`docs/PRD.md`](./docs/PRD.md) · [`docs/tech-design.md`](./docs/tech-design.md)
- 로드맵 (작업 체크리스트): [`docs/roadmap.md`](./docs/roadmap.md)
- **배포·잔여 실행 트랙:** [`docs/deploy-checklist.md`](./docs/deploy-checklist.md) (N1 스모크 → N2 Docker → … → N5 사람 PoC)
- 베타 직전(C): [`docs/invite-ops.md`](./docs/invite-ops.md) · [`docs/android-release.md`](./docs/android-release.md) · [`docs/prototype.md`](./docs/prototype.md)
- PoC 계획/준비물: [`docs/poc-plan.md`](./docs/poc-plan.md) · [`docs/poc-materials.md`](./docs/poc-materials.md)

## AI 에이전트 규칙

- [`AGENTS.md`](./AGENTS.md) · [`CLAUDE.md`](./CLAUDE.md)
- **브랜치:** 작업·머지는 항상 `main`
- **리모트:** GitHub `origin` + Gitea `gitea`(iykyka) — `main` 갱신 후 `./scripts/push-both.sh`

## 현재 단계

- Phase 1 **A~C**까지 반영됨 (서버·Flutter·베타 직전 문서/배포 경로)
- **다음:** [`docs/deploy-checklist.md`](./docs/deploy-checklist.md) — N1 스모크 → N2 `msn.iykyka.com` Docker → N3 안정화 → N4 FCM/Android QA
- **맨 마지막:** N5 / D — 사람 PoC #1/#3·Q3 인터뷰 (`docs/roadmap.md` §3). §3 기본값 추측 금지
- 프로토타입 공유 URL은 [`docs/prototype.md`](./docs/prototype.md)의 `SHARE_URL`에 Master가 기입

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

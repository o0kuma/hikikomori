# hikikomori / 분신 (가칭)

카카오톡 대안 메신저 — "나를 대신해 남과 대화하는 AI 분신".

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

- 기획: [`docs/PLANNING.md`](./docs/PLANNING.md) · 결정: [`docs/decision-log.md`](./docs/decision-log.md)
- Vision / PRD / 기술설계: [`docs/vision.md`](./docs/vision.md) · [`docs/PRD.md`](./docs/PRD.md) · [`docs/tech-design.md`](./docs/tech-design.md)
- 로드맵 (작업 체크리스트): [`docs/roadmap.md`](./docs/roadmap.md)
- PoC 계획/준비물: [`docs/poc-plan.md`](./docs/poc-plan.md) · [`docs/poc-materials.md`](./docs/poc-materials.md)

## AI 에이전트 규칙

- [`AGENTS.md`](./AGENTS.md) · [`CLAUDE.md`](./CLAUDE.md)

## 현재 단계

- 기획 문서 + Phase 1 **서버(Go/Python)** + Flutter **클라이언트 골격**까지 진행됨
- Q1~Q7은 아직 **잠정(제안)** — 회의 확정 전
- **사람 대상 PoC #1/#3·Q3 인터뷰는 맨 마지막 작업**으로 미룸 (`docs/roadmap.md` §3)

## 로컬 실행 (요약)

```bash
# 터미널 1 — AI 서비스
cd ai-service && pip install -r requirements.txt
export GEMINI_API_KEY=...   # or repo-root .env
uvicorn app.main:app --port 8001

# 터미널 2 — 코어 백엔드
cd core-backend && go run .

# 터미널 3 — Flutter (Android)
cd mobile && flutter run --dart-define=CORE_API_BASE=http://10.0.2.2:8080
```

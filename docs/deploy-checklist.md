# 배포·잔여 작업 체크리스트 (와카뷰)

Phase 1 **A~C** 이후 실행 트랙. 작업 단위를 하나씩 처리한다.
권위 문서: [`roadmap.md`](./roadmap.md) · [`decision-log.md`](./decision-log.md) · [`AGENTS.md`](../AGENTS.md).

**사람 PoC(D)와 Phase 1 §3 기본값은 맨 마지막.** 추측으로 채우지 않는다.

---

## 0. 통합 현황 (Claude + Cursor)

### DONE — Claude (`claude/project-planning-approach-ukdz31` 계열)

- [x] 기획 문서 세트 (`PLANNING`, vision/PRD/tech-design/risk/roadmap, decision-log 초안)
- [x] PoC #1/#3 계획·모집/역할극 자료·Q3 인터뷰 가이드·프로토타입 앵커
- [x] `poc/tone-corpus/` 파이프라인 (전처리·draft·escalation·retrieve·blind_eval)
- [x] 스택 확정: Flutter + Go core + Python AI
- [x] `core-backend/` · `ai-service/` · 하드게이트·거부권·초대·되돌리기·L0~L2 QA
- [x] Flutter UI 테마 폴리시 (`app_theme` + 화면별 시각 개선)

### DONE — Cursor 후속

- [x] A1/A2 API · A3 Flutter 메신저 연결 · API E2E (`scripts/e2e_a3.py`)
- [x] Phase 1 B (drift/SQLCipher, FCM 골격, sessions, metrics, data-flow, identity)
- [x] Phase 1 C (Q1~Q7 **확정**, invite-ops, Android release 경로)
- [x] Flutter Web SQLCipher stub · Twin Shadow UI · CORS · `DEMO-YKAVU`
- [x] GitHub + Gitea 듀얼 리모트 (`scripts/push-both.sh`)

### NOW

- 앱 코드는 클로즈드 베타 직전 수준
- 프로덕션 Docker **이미지·compose 준비 완료**. `msn.iykyka.com` **컷오버는 SSH/Portainer 자격 대기**
- 실 FCM · Android UI 수동 QA · 사람 PoC 실행은 남음

### NEXT 순서

```
N1 스모크 → N2 Docker(msn.iykyka.com) → N3 배포 안정화
         → N4 FCM·Android QA 등 → N5 사람 PoC(D) → 실제 베타 오픈
```

### LOCKED

- [ ] Phase 2+ (L3 / OS 레이어 / L4 / B2B) — Phase 1 게이트 전 구현 금지
- [ ] PoC §3 기본값(자율성 시작 레벨, 화이트리스트 기본 주제, 신뢰 UX 최종 카피) 추측 금지

---

## 항목 템플릿

각 ID를 처리할 때 아래로 상태를 갱신한다.

```text
Status: todo | doing | done | blocked
Depends on:
Acceptance: (체크리스트)
Notes:
```

---

## N1 — 배포 전 스모크

| ID | 작업 | Status | 완료 조건 |
|----|------|--------|-----------|
| **N1-1** | 서비스 기동 | **done** (2026-07-31) | `8080`/`8001`/`5555` health·web 200. 코어를 현재 `main`으로 재기동 (`ADMIN_API_TOKEN=dev-admin-token`, `ALLOW_DEMO_INVITE=1`) |
| **N1-2** | API E2E | **done** (2026-07-31) | `python3 scripts/e2e_a3.py` → **16 passed, 0 failed** |
| **N1-3** | Web 가입 스모크 | **done** (API) | `DEMO-YKAVU` 재사용 가입 + 토큰 발급 확인. `/demo` → `DEMO-YKAVU`. (브라우저 클릭 스모크는 로컬/테스터) |
| **N1-4** | 말투 온보딩 스모크 | **done** (코드경로) | 온보딩은 기기 로컬(drift); API 스모크에서는 대화 목록 진입 경로까지 확인. UI 탭은 테스터 |
| **N1-5** | 핵심 메신저 스모크 | **done** (API) | DEMO 두 유저 → 연락처 → 대화 → 메시지. E2E에 draft/L1·거부권·화이트리스트 포함 |
| **N1-6** | 프로덕션 CORS/API 메모 | **done** (2026-07-31) | 아래 Notes |

로컬 포트 참고: 앱 **5555**, 코어 **8080**, AI **8001**. Dart VM Service 고포트(예: 39369)는 디버그용 — 무시 가능.
데모 초대 코드(현재): **`DEMO-YKAVU`** (구 `DEMO-BUNSIN` 아님).

### N1-6 Notes — `msn.iykyka.com` 변경 목록

| 항목 | 로컬 지금 | 프로덕션 필요 |
|------|-----------|----------------|
| Flutter `CORE_API_BASE` | `http://127.0.0.1:8080` / emulator `10.0.2.2` | `https://msn.iykyka.com` (또는 API 서브경로/서브도메인 — compose에서 확정) |
| CORS Allow-Origin | `corsMiddleware()`가 요청 `Origin` 반사(로컬 `localhost:5555` 확인됨) | 동일 미들웨어면 same-origin 또는 `https://msn.iykyka.com` Origin 허용. 와일드카드+Credentials 조합 주의 |
| AI | `AI_SERVICE_URL=http://127.0.0.1:8001` | compose 내부 `http://ai-service:8001` (외부 미노출, N2-A3) |
| DB | SQLite `dev.db` | `DATABASE_URL=postgres://…` (N2-A2) |
| Admin | `ADMIN_API_TOKEN` env | Portainer secret (N2-A5) |
| Demo | `ALLOW_DEMO_INVITE=1`, `DEMO-YKAVU` | on 유지 (N2-A6) |
| WebSocket | `ws://host:8080` | `wss://msn.iykyka.com` (`AppConfig.wsBase`) |

---

## N2 — Docker 배포 (`https://msn.iykyka.com`) — Plan A

### N2-A. 착수 전 결정 (Master 확인)

| ID | 결정 | 값 | Status |
|----|------|-----|--------|
| **N2-A1** | 구 Node MSN 교체 | **교체(Plan A)** — `msn.iykyka.com`에 와카뷰 스택으로 컷오버 | **done** (2026-07-31 Master 확정) |
| **N2-A2** | DB | **PostgreSQL** (`tech-design.md` §8). compose에 `postgres` 서비스 + `DATABASE_URL`. SQLite는 로컬/테스트 전용 | **done** (2026-07-31 Master 확정) |
| **N2-A3** | AI 서비스 노출 | **내부망만** — 외부 포트/도메인 미공개, core-backend만 `AI_SERVICE_URL`로 호출 | **done** (2026-07-31 Master 확정) |
| **N2-A4** | 클라이언트 제공 | **Web 우선** — compose에 Flutter web 서빙. 내부 APK는 N4/릴리즈 경로로 후속 | **done** (2026-07-31 Master 확정) |
| **N2-A5** | 시크릿 관리 | **Portainer/호스트 env만** — `GEMINI_API_KEY`, `ADMIN_API_TOKEN`, DB 비밀번호, FCM 등 **git 커밋 금지** | **done** (2026-07-31 Master 확정) |
| **N2-A6** | 데모 초대 | 프로덕션 **`ALLOW_DEMO_INVITE=1` (on)** — 테스터용 `DEMO-YKAVU` 유지. 베타 확대 전 재검토 | **done** (2026-07-31 Master 확정) |

N2-A 전체 확정. 다음 구현 트랙은 **N1 스모크 → N2-B (Dockerfile/compose, Postgres 포함)**.

### N2-B. 이미지·compose

| ID | 작업 | Status | 완료 조건 |
|----|------|--------|-----------|
| **N2-B1** | `core-backend` Dockerfile | **done** | `core-backend/Dockerfile` — 이미지 빌드 성공 (`GOTOOLCHAIN=auto`, CGO) |
| **N2-B2** | `ai-service` Dockerfile | **done** | `ai-service/Dockerfile` — 이미지 빌드 성공 |
| **N2-B3** | Flutter web 빌드/서빙 | **done** | `mobile/Dockerfile` (flutter multi-stage) + `deploy/nginx-web.conf` (API/WS 프록시). 대안: `mobile/Dockerfile.prebuilt` |
| **N2-B4** | `docker-compose.yml` | **done** | root `docker-compose.yml` — postgres + ai(internal) + core(internal) + web 포트 |
| **N2-B5** | env 템플릿 | **done** | `.env.example`에 Postgres/`PUBLIC_API_BASE`/`WEB_HOST_PORT` 등 추가 |
| **N2-B6** | 데이터 볼륨 | **done** | compose 볼륨 `ykavu_pgdata` |
| **N2-B7** | 내부 DNS | **done** (정의) | compose 서비스명 `postgres` / `ai-service` / `core-backend`. *에이전트 VM은 bridge TCP 제한으로 런타임 검증 불가 — Portainer 호스트에서 확인* |
| **N2-B8** | CORS + API base | **blocked** | `PUBLIC_API_BASE=https://msn.iykyka.com` — 스택 Up 후 검증. *에이전트 SSH/Portainer 권한 없음* |
| **N2-B9** | 리버스 프록시 | **blocked** | OpenResty → `web` 포트. 절차 [`deploy-portainer.md`](./deploy-portainer.md) |
| **N2-B10** | Portainer 스택 | **blocked** | 절차 문서화 완료. Up은 Master 또는 자격 제공 후 |
| **N2-B11** | 구 MSN 컷오버 | **blocked** | 현재 `msn` = Express/`{"ok":true}` (구스택). 컷오버 절차 문서화됨 |
| **N2-B12** | 배포 스모크 | **blocked** | 컷오버 후 [`deploy-portainer.md`](./deploy-portainer.md) §C |
| **N2-B13** | 운영 runbook | **done** (초안) | [`deploy-docker.md`](./deploy-docker.md) · [`deploy-portainer.md`](./deploy-portainer.md) |

관련: Portainer `https://portainer.iykyka.com/`, SSH `iykyka@iykyka.com:7788` (키 필요). 시크릿 git 금지.

---

## N3 — 배포 직후 안정화

| ID | 작업 | Status | 완료 조건 |
|----|------|--------|-----------|
| **N3-1** | 헬스/로그 | todo | OOM·CORS·502 없음 |
| **N3-2** | 초대 발급 리허설 | todo | `docs/invite-ops.md` 절차 1회 |
| **N3-3** | admin metrics | todo | `/admin/metrics`·`/admin/dashboard` 토큰 조회 |
| **N3-4** | Gemini | todo | draft 1회 실호출 또는 mock 정책 명시 |
| **N3-5** | 백업 리허설 | todo | Postgres 덤프/복구 1회 (`pg_dump` 등) |
| **N3-6** | 테스터 안내 | todo | URL + 초대(`DEMO-YKAVU` 또는 개인 코드) + 주의사항 |

---

## N4 — 베타 품질 잔여

### FCM

| ID | 작업 | Status | 완료 조건 |
|----|------|--------|-----------|
| **N4-1** | Firebase + `google-services.json` | todo | Android 앱 연결 |
| **N4-2** | 실 FCM registration token | todo | install-id 플레이스홀더 제거 |
| **N4-3** | 서버 FCM 자격증명 | todo | env만 (`FCM_SERVER_KEY` 또는 HTTP v1) |
| **N4-4** | 푸시 수신 | todo | `/admin/push-test` + 에스컬레이션 수신 |

### Android UI 탭 (`mobile/README.md`)

| ID | 작업 | Status |
|----|------|--------|
| **N4-5** | 가입 → 말투 저장 | todo |
| **N4-6** | 연락처 → 대화 → 메시지·히스토리 | todo |
| **N4-7** | L1 초안 수정/버리기/승인·뱃지 | todo |
| **N4-8** | 에스컬레이션 → 사후알림 함 | todo |
| **N4-9** | 되돌리기·거부권 | todo |
| **N4-10** | 자율성 L0~L2 + 화이트리스트 | todo |

### 후순위

| ID | 작업 | Status | 비고 |
|----|------|--------|------|
| **N4-11** | 오프라인 메시지 큐 | todo | 멀티디바이스 고도화 |
| **N4-12** | 자연스러움 피드백 UI | todo | vision 지표 |
| **N4-13** | `prototype.md` `SHARE_URL` | todo | Master 기입 |
| **N4-14** | 내부 release APK | todo | `docs/android-release.md` |
| **N4-15** | roadmap/`[~]` 동기화 | todo | 완료 시 체크 |

---

## N5 — 사람 PoC (D) — **지금 열지 않음**

N1~N4(배포·품질에 필요한 최소분) 이후에만 착수. `roadmap.md` Phase 1 §3과 동일.

| ID | 작업 | Status |
|----|------|--------|
| **N5-1** | PoC #1/#3 참가자 모집·실행 | locked |
| **N5-2** | Q3 인터뷰 → 자율성 기본값 | locked |
| **N5-3** | 화이트리스트 기본 주제 | locked |
| **N5-4** | 신뢰 UX 문구/위치 확정 | locked |
| **N5-5** | vision 게이트 → 실제 클로즈드 베타 오픈 | locked |

자료: [`poc-plan.md`](./poc-plan.md) · [`poc-materials.md`](./poc-materials.md) · [`user-interview-guide.md`](./user-interview-guide.md).

---

## 바로 다음 5개 (권장)

1. ~~N2-A1~A6 결정 체크~~ **done**  
2. ~~N1 스모크~~ **done** (E2E 16/16 + DEMO API 경로; 브라우저 UI 탭은 테스터)  
3. ~~N2-B1~B7 이미지·compose~~ **done** (파일 랜딩·이미지 빌드)  
4. **N2-B8~B12** Portainer/SSH 컷오버 ← **blocked (자격 필요)** — [`deploy-portainer.md`](./deploy-portainer.md)  
5. **N3-6** 테스터 안내  

완료 시 본 표의 Status를 `done`으로 바꾸고, [`roadmap.md`](./roadmap.md) §4/§5의 대응 `[~]`/`[ ]`도 같이 갱신한다.

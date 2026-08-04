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
- [x] UI 2차 리디자인 — "아우로라 글래스"로 강화: 채도 높인 그라디언트+블러 글로우 orb, 고대비
  글래스 카드/그림자, `BrandMark`/`GradientText`/`PrimaryGradientButton` 신규 위젯으로 스플래시·
  가입·온보딩·대화목록 재적용. 실제 Flutter SDK 설치해 로컬 빌드+스크린샷(가입→온보딩→대화목록→
  채팅)으로 검증, 부수적으로 onboarding 헤더 뱃지가 `ListView` 직계 자식이라 전체폭으로 늘어나던
  기존 레이아웃 버그도 발견해 수정 (`Align`로 감쌈). **주의: GitHub `main`에는 반영됐지만
  `msn.iykyka.com` 프로덕션 재배포는 안 됨** — 이 작업 세션은 iykyka 호스트 접근 권한이 없어
  `scripts/server-up.sh` 재기동은 Master가 해당 호스트에서 직접 해야 함

### DONE — Cursor 후속

- [x] A1/A2 API · A3 Flutter 메신저 연결 · API E2E (`scripts/e2e_a3.py`)
- [x] Phase 1 B (drift/SQLCipher, FCM 골격, sessions, metrics, data-flow, identity)
- [x] Phase 1 C (Q1~Q7 **확정**, invite-ops, Android release 경로)
- [x] Flutter Web SQLCipher stub · Twin Shadow UI · CORS · `DEMO-YKAVU`
- [x] GitHub + Gitea 듀얼 리모트 (`scripts/push-both.sh`)

### NOW

- 앱 코드는 클로즈드 베타 직전 수준
- **`https://msn.iykyka.com` 라이브 + N3 완료 + Gemini 실초안 OK + Track A/B 완료**
- **웹 고도화:** [`web-upgrade.md`](./web-upgrade.md) — W0~**W2 done** · 다음 W3~W7는 Wi 승인 후
- 후순위: **N4 Android FCM/UI** — Master 시크릿·실기기
- UI: **iMessage-inspired light default** + soft charcoal dark 프로덕션 반영
- **Track C 콘텐츠 갭 A~F**: 프로덕션 반영 완료 (`95422bb`대)
- **Q8 계정·설정 IA (2026-08-03 확정·구현):** 로그인 탭 · 설정 허브 · 로그아웃
- **문서 갭 잔여:** L2 의미 [`decision-log.md`](./decision-log.md) Q9 **제안** —
  [`account-settings-ia.md`](./account-settings-ia.md) §3. Master 확정 전 Q9 구현 금지
  (**웹 트랙에도 Q9 비범위**)
- 실 FCM 기기 수신 · Android 실기기 탭 · 사람 PoC 실행은 남음 (Android 트랙)

### NEXT 순서

```
N1 스모크 → N2 Docker(msn.iykyka.com) → N3 배포 안정화
         → N4-W 웹 고도화(W1→…→W7) 병행 가능
         → N4 Android FCM·UI QA 등 → N5 사람 PoC(D) → 실제 베타 오픈
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
| **N2-B8** | CORS + API base | **done** (2026-07-31) | `PUBLIC_API_BASE=https://msn.iykyka.com`. OPTIONS CORS + 가입 확인 |
| **N2-B9** | 리버스 프록시 | **done** (2026-07-31) | Nginx Proxy Manager host #7 → `ykavu-web-1:80` |
| **N2-B10** | Portainer 스택 | **done** (compose CLI) | 서버 `~/project/ykavu` 에서 `docker compose up -d --build` (Portainer UI 아님) |
| **N2-B11** | 구 MSN 컷오버 | **done** (2026-07-31) | `iykyk_msn-service` stop. NPM `msn.iykyka.com` → 와카뷰. 롤백: MSN start + NPM upstream 복구 |
| **N2-B12** | 배포 스모크 | **done** (2026-07-31) | `/health`=`status`, `/demo`=`DEMO-YKAVU`, root 200, DEMO 가입 OK |
| **N2-B13** | 운영 runbook | **done** | [`deploy-docker.md`](./deploy-docker.md) · [`deploy-portainer.md`](./deploy-portainer.md) |

관련: 라이브 `https://msn.iykyka.com` · 서버 path `~/project/ykavu` · web 포트 `8788`(+ NPM). 시크릿 git 금지.

---

## N3 — 배포 직후 안정화

| ID | 작업 | Status | 완료 조건 |
|----|------|--------|-----------|
| **N3-1** | 헬스/로그 | **done** (2026-07-31) | 전 컨테이너 healthy. 공개 `/health` OK. 최근 로그에 OOM/502 없음 |
| **N3-2** | 초대 발급 리허설 | **done** (2026-07-31) | `POST /invites` note=`N3-rehearsal` 발급·`GET /invites` 목록 확인 |
| **N3-3** | admin metrics | **done** (2026-07-31) | Bearer로 `/admin/metrics`·`/admin/dashboard` 200 |
| **N3-4** | Gemini | **done** (2026-07-31) | 서버 `GEMINI_API_KEY` 주입·ai-service 재기동. 라이브 draft `status=ok` (예: `딱히? ㅋㅋ`) |
| **N3-5** | 백업 리허설 | **done** (2026-07-31) | `pg_dump` gzip → restore test DB → drop. [`ops-backup.md`](./ops-backup.md) |
| **N3-6** | 테스터 안내 | **done** (2026-07-31) | [`tester-guide.md`](./tester-guide.md) |

---

## N4 — 베타 품질 잔여

### Track A — 메신저 UX (대화 열기 경로)

| ID | 작업 | Status | 완료 조건 |
|----|------|--------|-----------|
| **N4-A1** | 내 사용자 ID 표시·복사 | done | 대화목록·연락처에 `MyUserIdChip` |
| **N4-A2** | 연락처 원탭 대화 + ID 필수 | done | 숫자 peer ID 없으면 추가/대화 차단·안내 |
| **N4-A3** | 빈 상태·에러·L0 패널 | done | L0는「입력창으로 옮기기」 |
| **N4-A4** | 대화 목록 이름·밀도 | done | 연락처 표시명 매핑 |
| **N4-A5** | 프로덕션 web 재빌드 | done | `msn.iykyka.com` health 200 (`3d00b00`) |
| **N4-A6** | ID 없는 연락처 수정(PATCH)·배너 | done | 「ID 입력」으로 peer ID 보강 |

### Track B — 데모 콘텐츠 (테스터 페어링)

| ID | 작업 | Status | 완료 조건 |
|----|------|--------|-----------|
| **N4-B1** | `/demo` pairing_steps·notes | done | GET `/demo`에 페어링 단계 |
| **N4-B2** | 테스터 가이드 페어링 문서화 | done | `docs/tester-guide.md` ID 교환 플로우 |
| **N4-B3** | 가입 화면 페어링 안내 | done | Signup 데모 패널에 한 줄 팁 |
| **N4-B4** | 프로덕션 core+web 재배포 | done | `/demo` pairing_steps OK (`c7029ab`) |

### Track C — 콘텐츠 갭 (PRD P0 대비 미구현, 2026-07-31 발견)

`roadmap.md` §2.7과 동일 항목. `PRD.md` §3.1 P0 표 대조 결과 발견(2026-07-31), 2026-08-03
2차 재분석으로 D/E/F 추가. **우선순위: C1(단톡 따라잡기) → C2(관계별 페르소나) → C3(스팸 감지)
→ C4(자율성 상대별 예외) → C5(관계 메모 반영) → C6(답장 마감 알림)** — 단톡 따라잡기는 v1 MVP
시나리오 2개 중 하나인데 현재 0% 구현이라 완성도 공백이 가장 큼; C4는 P0 명시 항목이지만
오버라이드 메커니즘 자체가 없어 C1~C3 다음; C5는 필드/UI가 이미 있고 프롬프트 주입만 빠져
비용이 가장 작음; C6은 P1이자 신규 구현 분량이 가장 커서 맨 마지막.

| ID | 작업 | Status | 완료 조건 |
|----|------|--------|-----------|
| **N4-C1a** | 그룹 대화 생성 UI(복수 상대) | **done** (2026-08-03) | "새 대화" 다이얼로그가 상대 여러 명 입력 받아 `is_group:true`로 생성 |
| **N4-C1b** | `GET /conversations/:id/summary` | **done** (2026-08-03) | `core-backend/group_summary.go` + 읽음 마커(`POST /conversations/:id/read`) |
| **N4-C1c** | 단톡 요약 생성(멘션/결정사항 3~5줄) | **done** (2026-08-03) | `ai-service/app/summarize.py` + `POST /summarize` |
| **N4-C1d** | 요약→초안 버튼 연결 (L0 고정) | **done** (2026-08-03) | `chat_screen.dart`. 서버가 그룹 대화 트윈 발송을 전역 레벨과 무관하게 항상 차단 |
| **N4-C1e** | "안 본 동안" 배지 | **done** (2026-08-03) | 대화 목록에 서버 계산 `unread_count` 표시 |
| **N4-C2a** | `relationship_tier` 필드(가까운/공식적) | **done** (2026-08-03) | `core-backend/models.go` `TwinSettings`(전역 기본값)·`Contact`(상대별 오버라이드) 확장 |
| **N4-C2b** | 온보딩 관계 티어 선택 스텝 | **done** (2026-08-03) | `onboarding_tone_screen.dart`, 말투 샘플 다음에 전역 기본값 선택 |
| **N4-C2c** | 연락처별 관계 티어 오버라이드 | **done** (2026-08-03) | `contacts_screen.dart` `_RelationshipTierPicker`, 자율성 설정 화면에 전역 기본값 변경 UI |
| **N4-C2d** | 초안 생성 시 티어별 톤 프롬프트 분기 | **done** (2026-08-03) | `ai-service/app/generation.py` `RELATIONSHIP_TIER_INSTRUCTIONS` + `core-backend/persona.go` `resolveRelationshipTier()`(연락처 오버라이드 → 전역 기본값 → `formal`) |
| **N4-C3a** | 짧은 시간 내 동일 상대 도배 감지 → 응대 일시중단 | **done** (2026-08-03) | `core-backend/flood_detect.go`(`floodMessageThreshold=5`건/`floodWindow=2분`, 안전 최소값 placeholder) + `main.go` `POST /conversations/:id/messages`의 peer-veto·그룹차단 다음, 에스컬레이션 이전 지점(우회 불가). `Conversation.TwinDisabledByFlood`로 대화방 단위 차단, `POST /conversations/:id/flood-reset`로 재개(거부권과 달리 되돌리기 가능) |
| **N4-C3b** | 도배 중단 시 사후 알림 | **done** (2026-08-03) | 기존 `EscalationLog`/`InboxScreen` 그대로 재사용(신규 알림 경로 없음). 대화 목록·채팅방 배너에 상태 표시 + "자동응대 재개" one-tap undo 버튼 추가 |
| **N4-C4a** | `Contact.AutonomyLevel` 오버라이드 필드 | **done** (2026-08-03) | `core-backend/models.go`, `RelationshipTier`와 동일 패턴(nil = 전역 기본값) |
| **N4-C4b** | 자율성 레벨 해석 함수 + 발송 게이트 교체 | **done** (2026-08-03) | `core-backend/autonomy_resolve.go` `resolveAutonomyLevel()`(연락처 오버라이드 → 전역 기본값 → `L0`, `resolveRelationshipTier`와 동일 구조). `main.go` `POST /conversations/:id/messages`가 전역값만 읽던 부분을 이 함수 호출로 교체 — peer-veto·그룹차단·도배 감지·에스컬레이션 순서는 그대로, "level" 계산만 교체. 그룹 대화는 이 함수 자체도 전역 기본값만 쓰고, 그 전에 걸리는 무조건 차단과 이중으로 안전 |
| **N4-C4c** | 연락처별 자율성 오버라이드 UI | **done** (2026-08-03) | `contacts_screen.dart` `_AutonomyLevelPicker`(`_RelationshipTierPicker` 옆, 기본값 사용/L0/L1/L2 4-way 칩), 연락처 목록 서브타이틀에도 표시 |
| **N4-C5a** | `draftRequest`에 `RelationshipNote` 필드 추가 | **done** (2026-08-03) | `core-backend/aiservice.go`, `relationship_tier` 옆 `omitempty`, 빈 문자열 = 무영향 |
| **N4-C5b** | draft 핸들러가 연락처 메모 조회해 전달 | **done** (2026-08-03) | `main.go` `POST /conversations/:id/draft` + `core-backend/persona.go` `resolveRelationshipNote()`. 그룹은 항상 빈 문자열(전역 기본 메모 개념 자체가 없음, 티어/자율성과 다른 지점). `resolveRelationshipTier`/`resolveAutonomyLevel`과 공유하는 `findCounterpartContact()` 헬퍼로 3중 복붙 제거 |
| **N4-C5c** | 메모를 톤 프롬프트에 주입 | **done** (2026-08-03) | `ai-service/app/generation.py` `system_prompt_for_tier(relationship_tier, relationship_note)`가 `"[관계 메모] {note} -- ..."` 문단 추가(빈 값/`None`이면 무영향, 관계 티어 지침과 별도 문단이라 안 섞임). 에스컬레이션/정체성 게이팅에는 영향 없음 |
| **N4-C6a** | "이따 답장" 스누즈 저장 | **done** (2026-08-03) | 순수 온디바이스 — `mobile/lib/db/tables.dart` `ConversationSnoozes` drift 테이블(서버 전송 없음), `chat_screen.dart` 앱바 "이따 답장" → 빠른 선택(1시간 후/저녁에/내일) + 해제, 실제 답장 전송 시 자동 해제 |
| **N4-C6b** | 리마인드 로컬 알림(본인에게만) | **done (부분 검증)** (2026-08-03) | `flutter_local_notifications`+`timezone` 실제 연동(`mobile/lib/services/snooze_notification_service_native.dart` `zonedSchedule`/`cancel`) — **단, 이 샌드박스에는 실기기/에뮬레이터가 없어 알림이 실제로 울리는지/탭 동작은 검증 불가**. 검증한 건 스케줄러를 목(mock)으로 바꿔 id·시각·페이로드가 올바른지뿐(`test/snooze_controller_test.dart`). 웹 빌드는 플러그인이 웹 미지원이라 `snooze_notification_service_web.dart` no-op 스텁. 실기기 검증 전까지는 대화 목록/채팅방의 인앱 배지·배너(C6c)가 실질적인 리마인드 경로 |
| **N4-C6c** | 스누즈 표시/취소 UI | **done** (2026-08-03) | `chat_screen.dart`(앱바 아이콘 상태 + 마감 지난 스누즈 배너 + 해제 버튼), `conversation_list_screen.dart`(서브타이틀 아래 "답장 마감" 배지, 탭하여 바로 해제). 마감 판정은 순수 함수 `isSnoozePastDue()`로 분리해 고정 시각 단위 테스트(`test/snooze_service_test.dart`) |

### N4-W — 웹 고도화 — [`web-upgrade.md`](./web-upgrade.md)

데모/프리뷰 표면 유지. **Q9 비범위.** Wi 단위 승인 후 구현. 서버 FCM SA는 Android와 공유.

| ID | 작업 | Status | 비고 |
|----|------|--------|------|
| **N4-W0** | 제품 경계 · 문서 랜딩 | **done** (2026-08-04) | 성공 정의·비범위·규율 고정 |
| **N4-W1** | 웹 로컬 지속성 (prefs/idb) | **done** (2026-08-04) | `app_database_web.dart` SharedPreferences · Drift WASM 비채택 · 라이브 하드 리프레시 스모크는 배포 후 |
| **N4-W2** | 데모 메신저 UX | **done** (2026-08-04) | ≥900px 분할·WS 상태·ID 복사·웹 안내 배너 |
| **N4-W3** | 인앱·Notification API | todo | 스누즈/에스컬레이션 인지 · Push 전 단계 |
| **N4-W4** | Web Push (FCM + VAPID) | todo | Master: Firebase Web config · VAPID |
| **N4-W5** | PWA | todo | manifest 테마 정렬 · 셸 캐시만 |
| **N4-W6** | 테스터 가이드 | todo | `tester-guide.md` 웹 절 |
| **N4-W7** | 품질 (Playwright 등) | todo | 스모크 + 부록 수동 QA |

### FCM (Android) — [`fcm-setup.md`](./fcm-setup.md)

| ID | 작업 | Status | 완료 조건 |
|----|------|--------|-----------|
| **N4-1** | Firebase + `google-services.json` | doing | Master: 앱 등록됨 · JSON을 Android 빌드 PC에 배치 |
| **N4-2** | 실 FCM registration token | done* | `PushTokenService` — Firebase 있으면 실 토큰, 없으면 `install:` (*전송은 N4-1 후) |
| **N4-3** | 서버 FCM 자격증명 (HTTP v1) | doing | Master: `secrets/firebase-service-account.json` (레거시 서버 키 대신). 웹 W4와 공유 |
| **N4-4** | 푸시 수신 (Android) | blocked | N4-1+N4-3 후 `/admin/push-test` + 기기 수신 |

### Android UI 탭 (`mobile/README.md`)

API 계층은 프로덕션에서 검증됨 (`CORE_API_BASE=https://msn.iykyka.com` → e2e **16/16**, 2026-07-31).  
실기기/에뮬레이터 **화면 탭**은 Master 로컬에서 1회.

| ID | 작업 | Status | 비고 |
|----|------|--------|------|
| **N4-5** | 가입 → 말투 저장 | api-done | 실기기 UI 탭 남음 |
| **N4-6** | 연락처 → 대화 → 메시지·히스토리 | api-done | 실기기 UI 탭 남음 |
| **N4-7** | L1 초안 수정/버리기/승인·뱃지 | api-done | 실기기 UI 탭 남음 |
| **N4-8** | 에스컬레이션 → 사후알림 함 | api-done | 실기기 UI 탭 남음 |
| **N4-9** | 되돌리기·거부권 | api-done | 실기기 UI 탭 남음 |
| **N4-10** | 자율성 L0~L2 + 화이트리스트 | api-done | 실기기 UI 탭 남음 |

### 후순위

| ID | 작업 | Status | 비고 |
|----|------|--------|------|
| **N4-11** | 오프라인 메시지 큐 | **done (부분 검증)** (2026-08-03) | 서버는 이미 모든 메시지를 DB에 durable하게 저장 — 별도 큐를 새로 만들지 않고 `GET /conversations/:id/messages?since_id=`(신규, 파라미터 없으면 기존 전체 히스토리 그대로) + 클라이언트 WS 재연결(backoff 1s→2s→...→30s 캡, 성공 시 리셋, `mobile/lib/services/ws_client.dart`) + 재연결/앱 포그라운드 복귀 시 since_id 캐치업(`mobile/lib/screens/chat_screen.dart`)으로 gap을 메움. `core-backend/a1_a2_test.go`(`TestListMessagesSinceID`)와 `mobile/test/message_sync_test.dart`(backoff 계산 + 중복 없는 병합을 순수 함수로 뽑아 검증)로 확인한 부분과, **실제 소켓 재연결 타이밍·앱 백그라운드/포그라운드 전환에서 OS가 소켓을 어떻게 처리하는지는 단위 테스트로 증명 불가 — 실기기 Android QA 남음**(N4-C6b와 같은 프레이밍) |
| **N4-12** | 자연스러움 피드백 UI | **done (계측만)** (2026-08-03) | vision 지표. **PoC 실행/결론이 아니라 캡처 장치** — 실제 %는 N5 이후 실 사용 데이터로. 암묵 신호: `core-backend/models.go` `Message.DraftEdited`(nullable — 사람 메시지/구버전 클라는 nil, 트윈 승인-발송 경로에서 클라이언트가 `original_draft_text`를 같이 보내면 서버가 diff해 true/false) + `mobile/lib/screens/chat_screen.dart` `_sendTwinApproved`가 `_pendingDraft.text`(편집 전 원본)를 함께 전송. 명시 신호: `Message.NaturalnessRating`(nullable bool) + `POST /messages/:id/feedback`(트윈 메시지만, 400 아니면 재제출은 덮어씀 — 409 아님) + `chat_screen.dart`/`message_bubble.dart`의 "이 답장 나답아요?" 원탭 👍/👎(한 번 탭하면 그 세션에서 다시 안 보여줌, `_ratedMessageIds` + `message_sync.dart`의 `ratedMessageIdsFrom()`). `/admin/metrics`에 `draft_unedited_rate`/`naturalness_positive_rate`(둘 다 분모 0일 때 0으로 zero-guard, `peer_veto_rate`와 동일 패턴) 추가, `adminDashboardHTML`에 카드 2개 추가. 백엔드 테스트 8개(`core-backend/main_test.go`) + 모바일 테스트 5개(`mobile/test/`) 추가, 전부 통과 |
| **N4-13** | `prototype.md` `SHARE_URL` | todo | Master 기입 |
| **N4-14** | 내부 release APK | todo | `docs/android-release.md` |
| **N4-15** | roadmap/`[~]` 동기화 | **done** (2026-08-03) | `roadmap.md` §2.1 "푸시 알림 서비스 연동"(낡은 중복 표기 → §B/N4-1~4로 교차참조), §4-4번 "남은 것"(완료된 "C 배포 준비" 제거), §2.3 온보딩 뼈대(관계 티어 스텝 추가 반영), §2.5 수동 QA 항목(N4-5~10/N4-C6b/N4-11 교차참조)을 실제 코드 상태와 맞춤. 나머지 `[~]`(FCM 푸시, 멀티디바이스 동기화, 데이터 프라이버시, L2 카피/수신트리거)는 실제로 아직 Master 액션·Q9 확정 대기 중이라 그대로 유지 — 허위로 채우지 않음 |

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
4. ~~N2-B8~B12 컷오버~~ **done** (`msn.iykyka.com` 라이브)  
5. ~~N3 안정화 + Track A/B~~ **done**, ~~Track C1 단톡 따라잡기~~ **done** (2026-08-03),
   ~~Track C2 관계별 페르소나~~ **done** (2026-08-03), ~~Track C3 스팸/도배 감지~~ **done**
   (2026-08-03) — **Track C 콘텐츠 갭 A/B/C 전체 완료.** 2026-08-03 2차 재분석으로 D/E/F 추가
   발견, ~~Track C4 자율성 상대별 예외~~ **done** (2026-08-03), ~~Track C5 관계 메모 반영~~
   **done** (2026-08-03), ~~Track C6 답장 마감 알림~~ **done(부분 검증)** (2026-08-03) —
   **2026-08-03 2차 갭 분석 배치(C4/C5/C6) 전체 구현 완료.** C6은 온디바이스 스누즈
   저장·UI는 완전히 검증(단위 테스트)됐지만, 실제 OS 로컬 알림이 실기기에서 울리는지는
   이 샌드박스(실기기/에뮬레이터 없음)에서 검증 불가 — Android UI QA(N4-5~10)에서 처음
   확인 필요, 그때까지는 인앱 배지·배너가 실질적 대체 경로. Track C A~F 프로덕션
   재배포는 **완료** (`95422bb` / docs `f363e8e`, 2026-08-03).

**바로 다음 (웹):** [`web-upgrade.md`](./web-upgrade.md) **W3** (인앱·Notification) — Wi 승인 후.
W0~W2 **done**. Android는 **N4-1/3 → N4-4 → N4-5~10** 후순위 병행.


완료 시 본 표의 Status를 `done`으로 바꾸고, [`roadmap.md`](./roadmap.md) §4/§5의 대응 `[~]`/`[ ]`도 같이 갱신한다.

# 로드맵 & 마일스톤

`decision-log.md`의 Q3(자율성 단계), Q7(자체앱→OS레이어 순서)에 따른 단계별 계획.
각 단계는 이전 단계의 핵심 가설이 검증되어야 다음으로 넘어간다 — 일정보다 검증 결과가 게이트다.

## Phase 0 — 기술 PoC (착수 즉시)

- 온디바이스 말투 학습 품질 검증 (`PLANNING.md` §4 PoC #1)
- 에스컬레이션 판정기(규칙 기반) 최소 프로토타입으로 오탐/누락 감 잡기
- 목표: "분신이 나답게 느껴지는가"에 대해 Go/No-Go 판단 근거 확보

## Phase 1 — v1 클로즈드 베타 (자체 앱, `PRD.md` 범위)

- 자율성 L0~L2, 시나리오: 읽씹 종결 + 단톡 따라잡기
- 안드로이드 우선, 초대 기반 소규모 베타 (지인 네트워크)
- 게이트: `vision.md` 성공 지표(자연스러움 70%, 거부율 10% 미만, 안전선 위반 0건) 충족 여부

### Phase 1 상세 작업 분해

원칙상 Phase 0(PoC) 검증 후 착수하는 게 맞지만, PoC 실제 실행(참가자 모집)이 보류된 지금
**PoC 결과와 무관한 기반 작업은 병행 착수**하고, **PoC 결과가 있어야 정할 수 있는 세부 값**은
자리만 비워두고 나중에 채우는 방식으로 진행한다. 아래 §3이 그 경계선이다.

이 체크리스트가 Phase 1 작업의 단일 기준이다 — 작업을 시작하기 전에 여기서 다음 항목을 확인하고,
끝나면 체크하고, 새로 발견한 하위 작업은 해당 항목 밑에 추가한다 (`AGENTS.md` "Phase 1 앱 빌드
작업 규칙" 참고).

#### 1. 착수 전 확정 필요 (기술 스택)

- [x] 기술 스택 결정 — `tech-design.md` §8 (Flutter/Dart 클라이언트, Go 코어 백엔드 +
  Python AI 서비스 투트랙, PostgreSQL, WebSocket 릴레이, drift+SQLCipher, Gemini 키 분리)

#### 2. 워크스트림별 작업

**2.1 코어 백엔드** (Go, PoC 결과 무관 — 지금 착수 가능)
- [x] 계정/인증 (초대 코드 기반 가입) — `core-backend/` (Go, Gin), 중복 코드 409 실제 테스트로 확인함
- [x] 메시지 릴레이 서버 (송수신) — `core-backend/` WebSocket + REST, 실제 테스트로 브로드캐스트 확인함.
  멀티 디바이스 동기화(같은 유저 여러 기기)는 아직 — 지금은 대화방 단위 인메모리 커넥션 매니저뿐
- [x] DB 스키마: users, invite_codes, contacts, conversations, messages, twin_settings,
  escalation_logs, whitelist_rules — `core-backend/models.go` (GORM), `backend/app/models.py`
  (Python 프로토타입)와 동일 스키마(+ invite_codes는 여기서 새로 추가)
- [ ] 푸시 알림 서비스 연동

`backend/`(Python 프로토타입)는 그대로 참고용으로 남겨둔다 — `core-backend/`(Go)가 실제로 쓰는 것.

**2.2 AI 서비스** (Python, PoC 스크립트 → 내부 API로 승격)
- [x] `poc/tone-corpus/generate_draft.py`·`escalation_filter.py`·`retrieve_style.py`를 감싸는
  FastAPI 서비스로 승격 — `ai-service/` (`POST /draft`, style_examples/history 두 경로 +
  에스컬레이션 하드게이트 + 검증 오류 전부 실제 테스트로 확인함)
- [x] Go 코어가 이 서비스를 실제로 호출하는 클라이언트 코드 (`core-backend/`에서 `AI_SERVICE_URL` 사용)
  — `core-backend/aiservice.go`(`AIServiceClient.requestDraft`) + `POST /conversations/:id/draft`
  라우트, mock AI 서비스로 정상 프록시·404·400(스타일 소스 없음) 전부 실제 테스트로 확인함
- [x] 자율성 엔진(L0~L2) 오케스트레이션 최소 버전 — 2.5 QA에서 "자율성 플로우 통합 테스트"를 쓰려면
  실제 분기 로직이 있어야 해서 그때 구현함. 결정: 에스컬레이션 하드게이트(Go 코어, 이미 구현) →
  레벨 확인은 Go 코어 책임(`PATCH /users/:id/twin-settings`로 레벨 변경, 메시지 저장 시 레벨별 분기).
  L0 항상 차단, L1은 `approved:true` 필요, L2는 화이트리스트 매칭 시 즉시 자동발송·매칭 없으면 L1과
  동일. 에스컬레이션은 레벨/화이트리스트 무관 항상 우선. **간소화한 부분**: 검색(retrieve)→초안
  생성은 이미 있는 `/draft` 흐름을 그대로 쓰면 되므로 새로 만들지 않았고, 화이트리스트는
  `ContactID`(상대별) 무시하고 전역 키워드 매칭만 지원 — 대화방↔연락처 연결 모델이 아직 없어서
  (Flutter 클라이언트의 연락처 모델이 생긴 뒤 다시 설계 필요, `core-backend/README.md` 참고)
- [x] 온디바이스 말투 이력 저장 + 서버 최소 전송 원칙 구현 — drift+SQLCipher(`mobile/lib/db/`),
  draft에 샘플만 전달, `DataFlowScreen`으로 원칙 노출
- [x] 사후 알림 + 되돌리기 로그 스키마/API — `escalation_logs`는 이미 쌓임(사후 알림용 로그).
  되돌리기(one-tap undo, AGENTS.md 안전 불변식)는 `Message.Retracted` 필드 +
  `POST /messages/:id/retract` 추가: 트윈이 자동발송한(L2) 메시지만 대상, 사람이 쓴 메시지는 400,
  이미 되돌린 건 409, 성공하면 같은 대화방 WebSocket에 `{"type":"retraction", "id":...}` 브로드캐스트.
  일반 메시지 브로드캐스트도 `"type":"message"`를 붙여 클라이언트가 두 이벤트를 구분하게 함.
  **되돌리기 UI는 `mobile/`에 있음**. 사후알림 함은 A3에서 `InboxScreen` +
  `GET /users/:id/escalation-logs`로 연결. FCM 푸시는 B.

**2.3 클라이언트 (Flutter, 안드로이드 우선 빌드)** — `mobile/`
- [x] 기본 채팅 UI (대화 목록, 대화방) — `GET`/`POST /conversations`, 히스토리 로드,
  WebSocket 수신·인간 메시지 전송. 연락처 화면에서 DM 시작
- [~] 온보딩 플로우(5분 온보딩) 뼈대 — 가입 + 말투 샘플 입력 UI(`OnboardingToneScreen`,
  기기 로컬). 말투 학습 UX 디테일·카피는 **사람 PoC #1 결과를 맨 마지막에 반영**
- [x] 분신 뱃지·거부권 UX — 점선+뱃지 말풍선, 대화방 거부권 버튼. 실시간 본인확인 응답 문구는
  서버/AI 프롬프트 측과 이어서 다듬을 것
- [x] 자율성 설정 화면(L0~L2, 화이트리스트) — `AutonomySettingsScreen`. 상대별 예외는
  서버 contact-scoped 매칭과 함께 화이트리스트 CRUD
- [x] 에스컬레이션·L1 승인·되돌리기 UI — L1 수정/버리기/재초안/승인 패널 + twin 되돌리기 +
  사후알림 함. FCM 푸시는 B

**2.4 안전장치 통합** (전 구간 필수, 타협 불가)
- [x] 에스컬레이션 하드게이트가 클라이언트·서버 전 구간에서 우회 불가하게 설계 — 실제 발견한 우회
  구멍: `POST /conversations/:id/messages`가 `sender_mode: "twin"`을 검증 없이 그대로 저장·
  브로드캐스트하고 있었음(초안 생성(`/draft`)만 게이트를 탔고, 발송 자체는 게이트가 없었음). 이걸
  막기 위해 `ai-service`에 `/draft`와 별개인 `POST /escalate/check` 하드게이트 엔드포인트를 추가하고,
  `core-backend`가 트윈 발송 저장 *직전에* 무조건 이걸 호출하도록 만듦 — 어떤 경로로 왔든 발송이
  실제로 일어나는 단 하나의 지점(메시지 저장)에서 걸리므로 클라이언트가 뭘 하든 우회 불가.
  AI 서비스 응답 불가 시 fail-safe(발송 차단, 502)로 처리. 사람이 직접 보내는 메시지는 게이트 대상이
  아님. 차단·통과·게이트 불능 3케이스 전부 실제 테스트로 확인함 (`core-backend/main_test.go`)
- [x] **발견 및 수정**: 거부권(peer veto) 안전 불변식이 코드에 전혀 구현되어 있지 않았음 —
  `Contact.TwinDisabledByPeer` 필드만 스키마에 있고 어디서도 읽거나 쓰지 않았고, `tech-design.md`
  §4는 "대화방 단위 플래그"라는데 실제로는 상대(Contact) 단위로 모델링돼 있어 설계 문서와도
  불일치했음(2.6 작업 중 발견). `Conversation.TwinDisabledByPeer`로 옮기고 `POST
  /conversations/:id/veto` 추가, 메시지 발송 시 **거부권 → 에스컬레이션 → 자율성 레벨** 순으로
  체크(거부권이 전부보다 우선) — L2 화이트리스트 매칭 + `approved:true`여도 거부권이 켜져 있으면
  무조건 차단되는 것까지 테스트로 확인함
- [~] 데이터 프라이버시: 온디바이스 암호화, 삭제 플로우, 데이터 흐름 대시보드 — 서버 쪽 삭제
  플로우(`DELETE /users/:id`, 유저가 걸린 모든 행을 트랜잭션으로 삭제)만 완료·테스트함. 온디바이스
  암호화(drift+SQLCipher)와 실시간 데이터 흐름 대시보드는 Flutter(`mobile/`) 쪽 후속 작업

**2.5 QA/테스트**
- [x] `escalation_filter.py`의 자체 테스트를 정식 테스트 스위트로 승격, `generate_draft`·`retrieve_style`도
  동일하게 — `ai-service/tests/`(pytest, 34개), SELFTEST_CASES 승격 + Gemini 호출 mock + `/health`·
  `/escalate/check`·`/draft` FastAPI 엔드포인트 테스트까지 포함. `poc/tone-corpus/`의 ad-hoc
  `--selftest`는 실험 도구로 그대로 두고(승격 대상은 "실제 서비스"인 `ai-service/`), 별개로 유지
- [x] 자율성 플로우(L0→L1→L2) 통합 테스트 — `core-backend/main_test.go`. 위 2.2 최소 오케스트레이션
  구현과 함께: L0 차단, L1 미승인 차단/승인 시 발송, L2 화이트리스트 매칭 자동발송/비매칭 시 승인
  필요, 에스컬레이션이 레벨·화이트리스트·승인 여부와 무관하게 항상 우선한다는 것까지 6개 케이스
  전부 실제 테스트로 확인함
- [ ] 온보딩·채팅·설정 수동 QA — `mobile/` 골격 위에 실기기/에뮬레이터로 진행 (후속)

**2.6 베타 배포 준비**
- [x] 초대 기반 베타 가입 플로우 — **발견**: 기존 가입은 "아무 문자열이나 처음 쓰면 통과"라
  실제로는 초대 기반이 아니었음. `InviteCode` 테이블 + `POST /invites`(발급) 추가하고
  `/auth/signup`이 미리 발급된 미사용 코드인지 검증하도록 변경(모르는 코드 400, 이미 쓴 코드
  409). 계정 삭제 시 코드는 "사용됨" 상태를 유지한 채 유저 참조만 지움. **아직 없는 것**: 발급자
  인증(`/invites`를 지금은 누구나 호출 가능 — 세션/인증 도입 시 같이 잠글 것)
- [~] `vision.md` 성공 지표(자연스러움·거부율·안전선 위반) 계측용 분석/피드백 수집 — 거부율은
  `/admin/metrics`의 `peer_veto_rate`로 1차 근사 가능해짐(대화방 단위, 확정 정의 아님). 자연스러움
  피드백 수집 UI는 Flutter 클라이언트 책임이라 보류. 안전선 위반 0건은 런타임에 "수집"하는 지표라기
  보다 지금까지의 하드게이트 테스트들이 이미 보증하는 것 — 별도 계측 불필요
- [~] 모니터링 대시보드 (에스컬레이션 트리거율, 생성 지연시간, 오류율) — `GET /admin/metrics`로
  카운트 기반 데이터(메시지 수, 에스컬레이션 사유별 집계, 거부권 발동률, 초대 코드 발급/사용 수)는
  노출함. **대시보드 UI 자체와 생성 지연시간·오류율**은 아직 없음 — UI는 Flutter/관리자 웹 쪽이고,
  지연시간·오류율은 요청 타이밍/로깅 계측 계층이 따로 필요해서 이번엔 만들지 않음(허위로 채우지
  않고 명시적으로 비워둠)

#### 3. PoC 결과가 있어야 정할 수 있는 것 — **전체 빌드가 끝난 뒤 맨 마지막**

**사람 대상 PoC #1/#3·Q3 인터뷰는 지금 실행할 수 없으므로 맨 마지막 작업으로 미룬다.**
§2 워크스트림(서버+Flutter)과 푸시/세션 등 남은 인프라가 끝난 뒤에만 이 섹션으로 돌아온다.
PoC 데이터 없이 기본값을 추측해 채우지 않는다.

- [ ] 사람 PoC #1/#3 실제 실행 + Q3 인터뷰 (참가자 모집 포함) — **맨 마지막**
- [ ] 자율성 기본값(L1 vs L2 어디서 시작할지) — Q3 인터뷰 필요
- [ ] 화이트리스트 기본 주제 목록 — 실사용 데이터 필요
- [ ] 신뢰 UX 문구/노출 위치 최종 확정 — PoC#3 결과 필요
- [ ] 실제 베타 오픈 시점 — `vision.md` 게이트 통과 필요

#### 4. 권장 착수 순서 (진행 상황)

순서대로 하나씩 완료하고 다음으로 넘어간다. **사람 PoC(§3)는 1~5번이 전부 끝난 뒤 맨 마지막.**

1. [x] §1 기술 스택 결정 (Go 코어 + Python AI 서비스로 재확정, `backend/`는 Python 프로토타입 —
   설계 참고용으로 남기고 Go로 포팅 필요)
2. [x] 2.1 코어 백엔드 Go 구현 — `core-backend/` (가입·메시지·WebSocket + A1 대화/연락처/히스토리 + A2 세션/관리자 토큰). 푸시 알림만 남음
3. [x] 2.2 AI 서비스 — `ai-service/`(Python) 완료. Go 코어→AI 서비스 연동·자율성 오케스트레이션·
   되돌리기 API 완료. 온디바이스 말투 이력 저장은 클라이언트와 이어서
4. [~] 2.3 Flutter 클라이언트 — A3까지 완료 + API E2E(`scripts/e2e_a3.py`). 남은 것: B
   (drift+SQLCipher·FCM 등), Android UI 탭은 실기기에서 `mobile/README.md` 체크리스트로
5. [x] 2.4/2.5 안전장치·QA (서버 쪽) — 하드게이트·거부권·삭제·pytest·L0~L2 통합 테스트 완료.
   클라이언트 쪽 온디바이스 암호화·데이터 흐름 대시보드·수동 QA는 B/A3 나머지와 함께
   - 5-1. [x] 2.6 베타 배포 준비(서버 쪽) — 초대 코드·`/admin/metrics`. **실제 베타 오픈은
     §3(사람 PoC) 이후**
   - 5-2. [x] 화이트리스트 규칙 CRUD API
6. [ ] §3 사람 PoC 실행 + 확정 값 반영 → 2.6 실제 베타 오픈 (**맨 마지막**)


#### 5. 앞으로의 개발 계획 (우선순위 체크리스트)

Master 합의 착수 순서: **A → B → C → D(맨 마지막)**. E는 Phase 게이트 전 구현 금지.

##### A. 지금 바로 — 앱이 실제로 돌아가게

**A1. 서버 — 대화/관계 모델 완성**
- [x] 대화방 생성·목록 API (`POST`/`GET /conversations`)
- [x] 연락처 CRUD + 대화방↔연락처 연결
- [x] 메시지 히스토리 조회 (`GET /conversations/:id/messages`)
- [x] 상대별 화이트리스트/자율성 예외 매칭
- [x] 에스컬레이션 로그 조회 API

**A2. 인증·보안**
- [x] 로그인 세션/토큰 (`Session`, signup/login 시 Bearer 발급)
- [x] `/invites`, `/admin/metrics` 접근 제어 (`ADMIN_API_TOKEN`)
- [x] 프로덕션 DB 마이그레이션 명령 (`go run . migrate`)

**A3. Flutter — 메신저답게 다듬기** (A1/A2 이후)
- [x] 대화 목록/연락처 UI를 서버 API에 연결
- [x] 온보딩 뼈대 확장 (말투 샘플 입력 UI)
- [x] L1 승인 플로우 UX 정리
- [x] 사후 알림 함
- [x] E2E QA — `scripts/e2e_a3.py`로 A3 HTTP 플로우 16/16 통과(가입·연락처·대화·히스토리·
  draft/L1·에스컬레이션·알림 로그·되돌리기·거부권·화이트리스트). `go test`/`pytest`/`flutter test`
  동시 통과. Android 에뮬레이터 UI 탭은 이 환경에 SDK가 없어 체크리스트는 `mobile/README.md`에 유지

##### B. 그다음 — 베타 품질
- [~] FCM 푸시 연동 — 토큰 등록 + 에스컬레이션 시 `notifyUser` + `POST /admin/push-test`.
  `FCM_SERVER_KEY`와 실제 FCM registration token이 있으면 전송, 없으면 soft-skip.
  Flutter는 install-id 플레이스홀더 등록(Firebase Messaging 앱 키는 배포 환경에서 교체)
- [~] 멀티 디바이스 동기화 — 세션 목록 + 세션 종료(`DELETE /users/:id/sessions/:id`).
  메시지 히스토리 서버 동기화는 이미 REST/WS; 오프라인 큐는 후속
- [x] drift + SQLCipher 로컬 저장 — `mobile/lib/db/` (말투 샘플·KV). 키는
  `flutter_secure_storage`. Linux CI는 SQLCipher SO 없으면 메모리 폴백
- [x] 말투 이력 기기 내 저장 + 서버 최소 전송 — drift 암호화 저장, draft에 샘플만 전달
- [x] 데이터 흐름 표시 UI — `DataFlowScreen`
- [x] 생성 지연시간·오류율 계측 — process-local `RuntimeMetrics` → `/admin/metrics`
- [x] 모니터링 대시보드(최소) — `GET /admin/dashboard`
- [x] 본인확인 응답 문구 고정/검증 — `ai-service/app/identity.py` + draft 경로 테스트

##### C. 베타 직전
- [ ] Android 릴리즈 빌드·서명·배포 경로
- [ ] 초대 코드 운영 절차(발급자 권한)
- [ ] Q1~Q7 회의 확정 (제안 → 확정)
- [ ] 클릭 프로토타입 공유 링크 docs 고정

##### D. 맨 마지막 — 사람 PoC (지금 안 함)
- §3 항목과 동일. A~C 완료 후에만 착수.

##### E. 베타 이후 (지금은 설계만, 구현 금지)
- Phase 2 L3 / Phase 3 OS 레이어 / Phase 4 L4·B2B


## Phase 2 — L3 확장 + 베타 확대

- 자리비움 전면 응대(L3) 추가 — Phase 1에서 신뢰가 검증된 경우에만
- 관계 메모, 답장 마감 알림 등 P1 기능
- 베타 규모를 소규모 지인 네트워크 밖으로 확대

## Phase 3 — OS 레이어 진입 (성장 전략)

- 전제: Phase 1 자체 앱 베타에서 핵심 가설이 검증된 뒤에만 착수 (`decision-log.md` Q7)
- 읽기 전용 허브부터 (발송 권한 없음, 문자·이메일 등 안정적 API 채널 우선)
- OS 레이어 내부 순서: 읽기 전용 → 초안 제안 → 제한적 자동응대(L2 그대로 확장)
- 확산 후 완전한 기능(L3·L4 등)이 필요하면 자체 앱으로 유도 — 시작 순서를 뒤집는 뜻이 아님
- 안드로이드 우선, iOS는 이 단계 반응을 본 뒤 자체 앱 전환 유도 전략으로 대응

## Phase 4 — L4 분신 협상 + B2B 확장

- 사용자 기반이 어느 정도 쌓여 네트워크 효과가 의미 있을 때 착수
- 기업용 고객 응대 분신(B2B)은 이 시점 이후 별도 트랙으로 검토

## 명시적으로 지금 계획하지 않는 것

- Phase 1 게이트를 통과하기 전에 Phase 2 이후 기능을 설계/개발하지 않는다.
- OS 레이어와 자체 앱을 동시에 만들지 않는다 (`decision-log.md` Q7 근거).

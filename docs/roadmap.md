# 로드맵 & 마일스톤

`decision-log.md`의 Q3(자율성 단계), Q7(자체앱→OS레이어 순서)에 따른 단계별 계획.
각 단계는 이전 단계의 핵심 가설이 검증되어야 다음으로 넘어간다 — 일정보다 검증 결과가 게이트다.

## Phase 0 — 기술 PoC (착수 즉시)

- 온디바이스 말투 학습 품질 검증 (`PLANNING.md` §4 PoC #1)
- 에스컬레이션 판정기(규칙 기반) 최소 프로토타입으로 오탐/누락 감 잡기
- 목표: "와카뷰가 나답게 느껴지는가"에 대해 Go/No-Go 판단 근거 확보

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
- [x] 와카뷰 뱃지·거부권 UX — 점선+뱃지 말풍선, 대화방 거부권 버튼. 실시간 본인확인 응답 문구는
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
  암호화(drift+SQLCipher)와 데이터 흐름 UI는 Flutter(`mobile/`) B에서 반영

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
  409). 계정 삭제 시 코드는 "사용됨" 상태를 유지한 채 유저 참조만 지움. 발급자 인증은
  `ADMIN_API_TOKEN`(A2). 운영 절차·만료/회수는 C (`docs/invite-ops.md`)
- [~] `vision.md` 성공 지표(자연스러움·거부율·안전선 위반) 계측용 분석/피드백 수집 — 거부율은
  `/admin/metrics`의 `peer_veto_rate`로 1차 근사 가능해짐(대화방 단위, 확정 정의 아님). 자연스러움
  피드백 수집 UI는 Flutter 클라이언트 책임이라 보류. 안전선 위반 0건은 런타임에 "수집"하는 지표라기
  보다 지금까지의 하드게이트 테스트들이 이미 보증하는 것 — 별도 계측 불필요
- [~] 모니터링 대시보드 (에스컬레이션 트리거율, 생성 지연시간, 오류율) — `GET /admin/metrics`로
  카운트 기반 데이터(메시지 수, 에스컬레이션 사유별 집계, 거부권 발동률, 초대 코드 발급/사용 수)는
  노출함. **대시보드 UI 자체와 생성 지연시간·오류율**은 아직 없음 — UI는 Flutter/관리자 웹 쪽이고,
  지연시간·오류율은 요청 타이밍/로깅 계측 계층이 따로 필요해서 이번엔 만들지 않음(허위로 채우지
  않고 명시적으로 비워둠)

**2.7 콘텐츠 갭 — PRD 3.1 P0 대비 미구현 기능** (2026-07-31 발견, 2026-08-03 2차 재분석으로
2.7-D~F 추가)

`PRD.md` §3.1 P0 표와 실제 코드를 대조해 발견. **우선순위: 2.7-A → 2.7-B → 2.7-C → 2.7-D →
2.7-E → 2.7-F** (이유: 단톡 따라잡기는 v1의 2개 MVP 시나리오 중 하나인데 현재 0% 구현이라
완성도 공백이 가장 큼; 페르소나는 1:1·단톡 양쪽 초안 품질에 영향; 스팸 감지는 P0지만 "최소
버전"이라 상대적으로 작음; 자율성 상대별 예외는 P0에 명시된 항목인데 관계별 페르소나와 달리
오버라이드 메커니즘 자체가 없어서 우선순위 4; 관계 메모는 필드/UI는 이미 있고 프롬프트 주입
한 줄만 빠진 상태라 비용이 가장 작음; 답장 마감 알림은 P1이자 셋 중 가장 새로 만들어야 할
분량이 커서 맨 마지막).

**2.7-A 단톡 따라잡기** (`PRD.md` §2.3 — **완료** 2026-08-03)
- [x] 그룹 대화 생성 UI(복수 상대 추가) — `conversation_list_screen.dart`의 "새 대화" 다이얼로그가
  동적으로 상대 필드를 추가/삭제할 수 있게 됨. 2명 이상이면 자동으로 `is_group:true`로 생성
- [x] `GET /conversations/:id/summary` — `core-backend/group_summary.go`. 참가자별 읽음 마커
  (`ConversationParticipant.LastReadMessageID`)를 두고, 그 이후 메시지만 모아 AI 서비스로 전달.
  `POST /conversations/:id/read`로 마커 갱신. `GET /conversations`에도 `unread_count` 추가
- [x] 요약 생성 — `ai-service/app/summarize.py`(신규), "나에게 멘션된 것/결정된 사항" 위주 3~5줄
  + 답장 필요 항목 표시(`PRD.md` §2.3-②). `POST /summarize` 엔드포인트. 읽기 전용이라 escalation/
  identity 게이트 없음(아무것도 발송되지 않으므로)
- [x] 요약 내 "답장 필요" 항목 → 초안 버튼 연결 — `chat_screen.dart`의 안 본 동안 요약 다이얼로그에서
  바로 `_requestDraft()`로 이어감. **그룹 대화는 전역 자율성 레벨과 무관하게 서버(`main.go`)가
  트윈 발송 자체를 항상 차단** — 클라이언트도 L0 취급으로 렌더링(PRD §2.3-③, 안전 불변식 유지)
- [x] "안 본 동안" 배지(마지막 읽음 이후 새 메시지 수) — `conversation_list_screen.dart`, 서버가
  계산한 `unread_count`를 그대로 표시
- **주의**: 읽음 마커는 채팅방에 "들어올 때"가 아니라 "나갈 때"(`dispose()`) 찍는다 — 들어오는
  순간 찍으면 그 방을 여는 즉시 안 본 게 0이 되어 "안 본 동안 요약"이 항상 빈 결과만 보여주는
  버그가 생김(실제 Playwright로 스크린샷 찍어보다가 발견). 실시간 소켓 메시지는 화면이 열려
  있는 동안은 계속 읽음으로 따라가도 됨

**2.7-B 관계별 페르소나** (`PRD.md` §2.1-②·§3.1, 최소 2종 — **완료** 2026-08-03)
- [x] `relationship_tier` 필드 추가(가까운 사이/공식적인 사이, 전역 기본값) — `TwinSettings`에
  추가, 신규 유저 기본값은 안전 우선으로 `formal`. `Contact`에도 상대별 오버라이드 필드 추가
- [x] 온보딩에 관계 티어 선택 스텝 추가 — `onboarding_tone_screen.dart`, 말투 샘플 다음에 전역
  기본값 선택(`SegmentedButton`)
- [x] 연락처별 관계 티어 오버라이드 — `contacts_screen.dart` 연락처 추가/수정 다이얼로그에
  `_RelationshipTierPicker`(기본값 사용/가까운 사이/공식적인 사이 3-way 칩), 자율성 화면에도
  전역 기본값 변경 UI 추가
- [x] 초안 생성 시 상대 티어별 톤 프롬프트 분기 — `ai-service/app/generation.py`
  `RELATIONSHIP_TIER_INSTRUCTIONS` + `system_prompt_for_tier()`. `core-backend`가
  `POST /conversations/:id/draft` 호출마다 `resolveRelationshipTier()`로 해석(연락처 오버라이드
  → 전역 기본값 → `formal`) 해서 `ai-service`로 전달. 그룹 대화는 상대가 여럿이라 항상 전역
  기본값만 사용. 이 엔드포인트가 원래 인증을 요구하지 않던 걸 깨지 않도록 `currentUser(..., false)`로
  선택적 인증 처리 — 토큰 없는 기존 호출도 그대로 동작(티어 해석만 스킵)

**2.7-C 스팸/도배 감지 최소 버전** (`PRD.md` §4 엣지케이스: "안전 관련이라 v1 최소 버전 필요"로
명시 — **완료** 2026-08-03)
- [x] 짧은 시간 내 동일 상대 메시지 N건 초과 시 자동응대 일시중단 — `core-backend/flood_detect.go`
  (`floodMessageThreshold = 5`건 / `floodWindow = 2분`, **PoC 검증값이 아니라 안전 최소값으로
  명시한 v1 placeholder** — §3 "PoC 결과가 있어야 정할 수 있는 것"과는 성격이 다른, 반드시
  있어야 하는 기술적 안전장치라 임시값으로 우선 구현). `main.go`의 `POST
  /conversations/:id/messages`에서 peer-veto → 그룹 대화 차단 다음, 에스컬레이션 하드게이트
  이전 지점에 추가 — 트윈 발송 시도 전체가 지나가는 동일 우회 불가 지점. 카운트는 대화방 내
  `sender_id != 소유자`인 메시지(=상대가 보낸 것, 트윈 자동발송·소유자 본인 발송 모두 제외)만
  집계. `Conversation.TwinDisabledByFlood`로 대화방 단위 영구 차단(거부권과 동일 저장 패턴) —
  단, 거부권과 달리 **사람의 선택이 아닌 시스템의 자동 조치**라 되돌릴 수 있어야 해서(AGENTS.md
  "every automatic action needs post-hoc notification + one-tap undo") `POST
  /conversations/:id/flood-reset`로 재개 가능(거부권은 v1에서 되돌리기 API 없음, 의도적으로 다름)
- [x] 중단 시 사후 알림 — 기존 `EscalationLog`/`InboxScreen` 스키마·UI 그대로 재사용(신규 알림
  경로 없음). 대화 목록(`conversation_list_screen.dart`)에도 `twin_disabled_by_flood` 배지 추가
  (거부권 배지와 같은 자리, 다른 아이콘). 재개(one-tap undo)는 `chat_screen.dart`의 배너에
  "자동응대 재개" 버튼으로 노출 — 채팅방을 열면(목록에서 넘어온 초기 상태) 또는 발송 시도가
  다시 차단되면 즉시 뜬다

**2.7-D 자율성 상대별 예외** (`PRD.md` §3.1 "자율성 설정(L0~L2) | 전역 기본값 + 상대별 예외
설정", §4 엣지케이스 "사용자가 여러 상대에게 다른 자율성 레벨을 원함" — P0인데 현재 전역
`TwinSettings.AutonomyLevel` 하나뿐, `Contact`에 오버라이드 필드 자체가 없음, 2026-08-03 발견 —
**완료** 2026-08-03)
- [x] `Contact`에 `AutonomyLevel *AutonomyLevel` 오버라이드 필드 추가(`RelationshipTier`와
  동일 패턴, nil = 전역 기본값 사용) — `core-backend/models.go`
- [x] 자율성 레벨 해석 함수 추가(연락처 오버라이드 → 전역 기본값 → `L0`, `resolveRelationshipTier`
  와 동일 구조) — `core-backend/autonomy_resolve.go`의 `resolveAutonomyLevel()`. 메시지
  발송 게이트(`main.go` `POST /conversations/:id/messages`)가 `db.Where("user_id =
  ?", req.SenderID).First(&settings)`로 전역값만 읽던 걸 이 해석 함수 호출 한 줄로 교체 —
  peer-veto·그룹 차단·도배 감지·에스컬레이션 하드게이트는 순서 그대로 유지, "level" 계산
  방식만 바뀜. 실패 시 폴백은 `L1`/`L2`가 아니라 `L0`(이 코드베이스 전반의 안전 우선 기본값과
  동일한 이유 — 알 수 없으면 항상 초안만 만들고 사람이 직접 보냄)
- [x] 연락처 추가/수정 다이얼로그에 자율성 레벨 오버라이드 UI(`contacts_screen.dart`,
  `_RelationshipTierPicker`와 나란히 `_AutonomyLevelPicker`(기본값 사용/L0/L1/L2 4-way 칩) 추가,
  연락처 목록 서브타이틀에도 오버라이드 표시)
- [x] 그룹 대화는 기존과 동일하게 항상 전역 L0 취급 유지(단톡 따라잡기 안전 불변식 변경 없음) —
  `resolveAutonomyLevel()`도 `RelationshipTier`와 동일하게 그룹 대화면 연락처 오버라이드를
  건너뛰고 전역 기본값만 사용하도록 구현, 그룹 대화는 애초에 `main.go`의 무조건 차단이 이
  해석 함수 호출보다 먼저 걸려서 두 안전장치가 이중으로 겹침

**2.7-E 관계 메모 실제 반영** (`PRD.md` §3.2 P1, `Contact.RelationshipNote` 필드·CRUD는 이미
있으나 `draftRequest`에 필드 자체가 없어 ai-service 프롬프트에 전혀 전달되지 않음 — 저장만 되는
스텁, 2026-08-03 발견)
- [ ] `core-backend/aiservice.go`의 `draftRequest`에 `RelationshipNote string` 필드 추가
- [ ] `POST /conversations/:id/draft` 핸들러가 연락처의 `RelationshipNote`를 조회해 요청에 포함
  (그룹 대화는 상대가 여럿이라 관계별 페르소나와 동일하게 스킵하거나 대표 로직 결정 필요)
- [ ] `ai-service/app/generation.py`가 메모가 있으면 시스템 프롬프트에 "호칭/금기어" 지침으로
  주입(빈 문자열이면 기존과 동일하게 무영향)

**2.7-F 답장 마감 알림** (`PRD.md` §3.2 P1: "내가 '이따 답장' 누르면 나에게만 리마인드" — 코드
전무, 아이디어 회의 문서에만 존재, 2026-08-03 발견)
- [ ] 메시지/대화에 "이따 답장" 스누즈 액션 + 리마인드 시각 저장(서버 또는 온디바이스 — 개인
  전용 알림이라 온디바이스 우선 원칙에 맞는 쪽으로 설계)
- [ ] 리마인드 도달 시 로컬 알림(다른 사람에게는 보이지 않음, 본인에게만)
- [ ] `chat_screen.dart`/`conversation_list_screen.dart`에 스누즈 표시·취소 UI

**스코프 밖 (제안 아님, 참고용)**: 이미지/파일 전송·읽음표시·타이핑 인디케이터 등 "일반 메신저"
테이블스테이크 기능은 `PRD.md`에 명시되지 않음 — 콘텐츠 공백의 또 다른 후보일 수 있으나 이건
PRD 범위 확장이라 Master 결정이 먼저 필요. L3/L4/OS레이어/B2B는 `decision-log.md`/`AGENTS.md`
하드 밴 그대로 유지.

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
4. [~] 2.3 Flutter 클라이언트 — A3 + B(drift/SQLCipher·데이터흐름·세션) 완료 + API E2E.
   남은 것: 실제 Firebase FCM 토큰, Android UI 탭(`mobile/README.md`), C 배포 준비
5. [x] 2.4/2.5 안전장치·QA (서버 쪽) — 하드게이트·거부권·삭제·pytest·L0~L2 통합 테스트 완료.
   클라이언트 쪽 온디바이스 암호화·데이터 흐름 대시보드·수동 QA는 B/A3 나머지와 함께
   - 5-1. [x] 2.6 베타 배포 준비(서버 쪽) — 초대 코드·`/admin/metrics`. **실제 베타 오픈은
     §3(사람 PoC) 이후**
   - 5-2. [x] 화이트리스트 규칙 CRUD API
6. [x] Phase 1 C 베타 직전 — Q1~Q7 확정, 초대 운영, 프로토타입 앵커, Android 릴리즈 경로
   - 6-1. [x] 2.7 콘텐츠 갭 — PRD P0 대비 미구현 기능 (**우선순위: A 단톡 따라잡기 → B 관계별
     페르소나 → C 스팸 감지**, 2026-07-31 발견 — A/B/C 모두 완료 2026-08-03). §3 사람 PoC보다
     먼저 끝내야 함 — PRD가 요구하는
     v1 P0 범위이므로 §4 순서상 D(사람 PoC) 앞
7. [ ] §3 사람 PoC 실행 + 확정 값 반영 → 실제 베타 오픈 (**맨 마지막 / D**)


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
- [x] Android 릴리즈 빌드·서명·배포 경로 — `docs/android-release.md`,
  `scripts/build_release_apk.sh` / `build_release_aab.sh`, `key.properties` 서명 훅.
  keystore는 Master 로컬 전용(내부 APK 우선)
- [x] 초대 코드 운영 절차(발급자 권한) — `docs/invite-ops.md` + note/만료/배치/회수 API
  (`GET|POST /invites`, `POST /invites/:code/revoke`)
- [x] Q1~Q7 회의 확정 (제안 → 확정) — `docs/decision-log.md` (2026-07-30). PoC 의존 하위
  질문만 열어둠
- [x] 클릭 프로토타입 공유 링크 docs 고정 — `docs/prototype.md` 앵커. `SHARE_URL`은 Master 기입

##### D. 맨 마지막 — 사람 PoC (지금 안 함)
- §3 항목과 동일. A~C 완료 후에만 착수.
  **단, 프로덕션 Docker 배포·스모크(N1~N3)는 D보다 앞** — [`deploy-checklist.md`](./deploy-checklist.md).

##### E. 베타 이후 (지금은 설계만, 구현 금지)
- Phase 2 L3 / Phase 3 OS 레이어 / Phase 4 L4·B2B

#### 6. 배포·잔여 작업 (A~C 이후 실행 트랙)

단일 실행 체크리스트: **[`deploy-checklist.md`](./deploy-checklist.md)**.

순서: **N1 스모크 → N2 Docker(`msn.iykyka.com`) → N3 안정화 → N4 FCM/Android QA → N5 사람 PoC(D)**.
Claude/Cursor 통합 DONE 목록과 항목 ID(N1-1 … N5-5)는 해당 문서를 본다. 완료 시 그 문서와
본 로드맵 §2/§5의 `[~]`/`[ ]`를 함께 갱신한다.


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

## Phase 4 — L4 와카뷰 협상 + B2B 확장

- 사용자 기반이 어느 정도 쌓여 네트워크 효과가 의미 있을 때 착수
- 기업용 고객 응대 와카뷰(B2B)은 이 시점 이후 별도 트랙으로 검토

## 명시적으로 지금 계획하지 않는 것

- Phase 1 게이트를 통과하기 전에 Phase 2 이후 기능을 설계/개발하지 않는다.
- OS 레이어와 자체 앱을 동시에 만들지 않는다 (`decision-log.md` Q7 근거).

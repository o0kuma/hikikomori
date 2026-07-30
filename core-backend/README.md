# 분신 core-backend (Go)

Phase 1 코어 백엔드 (`docs/roadmap.md` Phase 1 §2.1). 스택 결정은 `docs/tech-design.md` §8 참고 —
Go(Gin + gorilla/websocket + GORM), PostgreSQL(프로덕션)/SQLite(로컬 개발). `../backend/`(Python
프로토타입)의 동작을 그대로 재현한 것이다 — API·DB 스키마는 거기서 이미 검증된 것과 동일하다.

## 실행

```bash
go mod download
go run .
```

기본은 `sqlite:./dev.db`로 뜬다. 프로덕션 DB를 쓰려면:

```bash
export DATABASE_URL="postgres://user:pass@host/dbname"
```

AI 서비스(`../ai-service/`)를 호출하려면:

```bash
export AI_SERVICE_URL="http://localhost:8001"   # 기본값도 이 주소
```

## 테스트

```bash
go test ./... -v
```

`main_test.go`가 초대 코드 발급/검증(400·409 포함)/메시지 저장/존재하지 않는 대화방(404)/WebSocket
브로드캐스트/초안 생성 프록시/에스컬레이션 하드게이트(차단·통과·게이트 불능 시 fail-safe)/자율성
플로우(L0 차단·L1 승인·L2 화이트리스트 자동발송·L2 비대상 승인 필요·에스컬레이션의 레벨 무관 우선)/
거부권(peer veto, 다른 모든 조건보다 우선)/계정 삭제/운영 지표까지 전부 mock AI 서비스로 실제로
돌려서 확인한다 (`../backend/`의 Python TestClient 테스트와 동일한 케이스 + Go에서 새로 추가된 것들).

## 지금 있는 것

**2.1 코어 백엔드**
- `GET /health` — 헬스체크
- `POST /auth/signup` — 초대 코드 기반 가입. 미리 발급된(`POST /invites`) 미사용 코드가 아니면
  400, 이미 쓴 코드면 409 (아래 2.6)
- `POST /conversations/{id}/messages` — 메시지 저장 + 같은 대화방 WebSocket 커넥션에 브로드캐스트.
  `sender_mode: "twin"`인 요청은 저장 전에 반드시 거부권·에스컬레이션 하드게이트를 통과해야 한다
  (아래 2.4)
- `POST /conversations/{id}/veto` — 거부권 발동: 이 대화방의 `twin_disabled_by_peer`를 켠다.
  이후 이 대화방에서는 어떤 자율성 레벨·화이트리스트·승인 여부와도 무관하게 트윈 자동발송이
  전부 차단된다 (아래 2.4). v1은 한 방향(끄기만 가능, 되돌리는 API 없음)
- `GET /ws/conversations/{id}` (WebSocket 업그레이드) — 대화방별 실시간 릴레이 (인메모리 커넥션 매니저)
- `DELETE /users/{id}` — 계정 삭제("초기화"): 해당 유저가 걸린 모든 행(트윈 설정·화이트리스트·
  연락처·대화 참여·메시지·에스컬레이션 로그·유저 본인)을 트랜잭션으로 삭제하고, 그 유저가 쓴
  초대 코드는 "사용됨" 상태는 유지한 채 유저 참조만 지운다 (`tech-design.md` §5 "사용자가
  언제든 초기화 가능")
- DB 모델 (`models.go`): `users`, `invite_codes`, `contacts`, `conversations`,
  `conversation_participants`, `messages`, `twin_settings`, `whitelist_rules`, `escalation_logs` —
  `../backend/app/models.py`와 동일한 스키마(+ `invite_codes`는 여기서 새로 추가)

**2.2 AI 서비스 연동**
- `POST /conversations/{id}/draft` — `ai-service/`의 `POST /draft`를 호출해 초안을 프록시 반환
  (`style_examples`/`history` 중 하나 필수, 없으면 400)

**2.4 안전장치 통합**
- 트윈 발송 시 체크 순서: **거부권 → 에스컬레이션 → 자율성 레벨**. 앞 단계에서 막히면 뒤 단계는
  아예 확인하지 않는다 — 순서가 바뀌면 안 되는 이유는 거부권/에스컬레이션이 레벨·화이트리스트·
  승인 여부보다 항상 우선해야 하기 때문 (테스트로 확인함)
- 거부권: `conversation.TwinDisabledByPeer`가 켜져 있으면 그 자리에서 403 — AI 서비스 호출조차
  하지 않는다. 사람이 직접 보내는 메시지는 영향받지 않는다
- `AIServiceClient.checkEscalation` (`aiservice.go`) — `ai-service`의 `POST /escalate/check` 호출.
  `/conversations/{id}/messages`가 `sender_mode: "twin"`을 받을 때마다 이걸 호출해서, 어떤
  경로로 왔든(그리고 `/draft`를 거쳤든 안 거쳤든) 트윈 자동발송은 전부 이 게이트를 통과하게 만드는
  하나의 초크포인트다. 에스컬레이션되면 메시지는 저장·브로드캐스트되지 않고 `escalation_logs`에
  기록만 남는다(403). AI 서비스가 응답하지 않으면 fail-safe로 발송 자체를 막는다(502) — 게이트를
  확인 못 했다는 불확실성을 자동발송 허용 쪽으로 풀지 않는다.
- 사람이 직접 보내는 메시지(`sender_mode` 기본값 `human`)는 이 게이트를 타지 않는다 — 본인이 직접
  쓴 말을 막을 이유가 없다.

**2.2/2.5 자율성 엔진(L0~L2) 최소 오케스트레이션** (PRD.md §2.1/§2.2, roadmap.md §2.5 QA 작업 중
필요해져서 구현)
- `PATCH /users/{id}/twin-settings` — `{"autonomy_level": "L0"|"L1"|"L2"}`로 전역 자율성 레벨 변경
  (가입 시 기본값은 L0, PRD.md §2.1)
- 에스컬레이션 통과 후 트윈 발송이면 레벨을 확인: **L0**은 항상 차단(403, 초안만 가능), **L1**은
  요청에 `approved: true`가 없으면 차단(403), **L2**는 `whitelist_rules`에 매칭되는 주제면
  `approved` 없이도 즉시 발송, 매칭이 없으면 L1과 동일하게 승인 필요
- 화이트리스트 매칭(`whitelistMatches`)은 v1 최소 구현 — 유저의 모든 `WhitelistRule.TopicKeyword`를
  메시지 텍스트에 부분 문자열로 매칭. `WhitelistRule.ContactID`(상대별 화이트리스트)는 아직 무시함 —
  대화방↔연락처 연결이 아직 모델링되어 있지 않아서(클라이언트 연락처 모델이 생긴 뒤에 다시 설계 필요)
- 레벨/화이트리스트와 무관하게 에스컬레이션이 항상 우선한다 — L2 화이트리스트 매칭 + `approved:
  true`여도 에스컬레이션 대상이면 무조건 차단 (테스트로 확인함)

**2.6 베타 배포 준비**
- `POST /invites` — 새 초대 코드 발급(무작위 10자 hex). 아직 발급자 인증이 없어 누구나 호출
  가능 — 인증/세션이 생기기 전까지는 서버 콘솔·내부 도구에서만 호출한다고 가정
- `GET /admin/metrics` — `users_total`·`messages_human_total`·`messages_twin_total`·
  `escalations_total`·`escalations_by_reason`·`conversations_total`·`conversations_vetoed`·
  `peer_veto_rate`·`invites_minted`·`invites_used`. 지금 스키마로 정직하게 계산 가능한 것만 —
  `peer_veto_rate`는 vision.md "분신 거부율" 지표의 1차 근사치(대화방 단위)이지 확정 정의는 아님.
  생성 지연시간·AI 서비스 오류율은 별도 계측/로깅 계층이 없어서 넣지 않음 (아래 "아직 없는 것")

## 아직 없는 것 (다음 워크스트림)

- 화이트리스트 규칙 CRUD API (지금은 DB에 직접 넣는 걸로 테스트함 — 유저가 화이트리스트를 실제로
  등록하는 API는 아직 없음, 2.3 자율성 설정 화면과 같이 설계 필요)
- 상대별(`ContactID`) 화이트리스트/자율성 예외 (지금은 전역 레벨만 지원)
- 온디바이스 말투 이력 저장 + 서버 최소 전송 (클라이언트 책임)
- 사후 알림 + 되돌리기 "UI" 흐름 (로그 자체는 쌓이지만, 사용자에게 보여주고 되돌리는 건 Flutter 쪽)
- 데이터 흐름 대시보드, 온디바이스 암호화 (둘 다 Flutter 클라이언트 책임 — 이 저장소엔 SDK 없어
  로컬 환경에서 진행)
- 생성 지연시간·오류율 계측 (요청 타이밍/로깅 계층 필요, `/admin/metrics`는 카운트만 있음)
- `/invites`·`/admin/metrics` 접근 제어 (지금은 인증이 없어 누구나 호출 가능 — 아래 인증 항목과 같이 해결)
- 푸시 알림 연동
- 인증 토큰/세션 (지금은 invite_code로 가입만 되고 로그인 세션 개념이 없음)
- 프로덕션 마이그레이션 도구 (지금은 `AutoMigrate`로 시작 시 테이블 생성 — 스키마 안정되면 Atlas/golang-migrate 등 도입)
- 멀티 디바이스 동기화 (같은 유저가 여러 기기로 접속하는 경우)

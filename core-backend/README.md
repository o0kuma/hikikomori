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

`main_test.go`가 가입/중복코드 거부(409)/메시지 저장/존재하지 않는 대화방(404)/WebSocket
브로드캐스트/초안 생성 프록시/에스컬레이션 하드게이트(차단·통과·게이트 불능 시 fail-safe)/계정
삭제까지 전부 mock AI 서비스로 실제로 돌려서 확인한다 (`../backend/`의 Python TestClient 테스트와
동일한 케이스 + Go에서 새로 추가된 것들).

## 지금 있는 것

**2.1 코어 백엔드**
- `GET /health` — 헬스체크
- `POST /auth/signup` — 초대 코드 기반 가입 (중복 코드는 409)
- `POST /conversations/{id}/messages` — 메시지 저장 + 같은 대화방 WebSocket 커넥션에 브로드캐스트.
  `sender_mode: "twin"`인 요청은 저장 전에 반드시 에스컬레이션 하드게이트를 통과해야 한다 (아래 2.4)
- `GET /ws/conversations/{id}` (WebSocket 업그레이드) — 대화방별 실시간 릴레이 (인메모리 커넥션 매니저)
- `DELETE /users/{id}` — 계정 삭제("초기화"): 해당 유저가 걸린 모든 행(트윈 설정·화이트리스트·
  연락처·대화 참여·메시지·에스컬레이션 로그·유저 본인)을 트랜잭션으로 삭제 (`tech-design.md` §5
  "사용자가 언제든 초기화 가능")
- DB 모델 (`models.go`): `users`, `contacts`, `conversations`, `conversation_participants`,
  `messages`, `twin_settings`, `whitelist_rules`, `escalation_logs` — `../backend/app/models.py`와
  동일한 스키마

**2.2 AI 서비스 연동**
- `POST /conversations/{id}/draft` — `ai-service/`의 `POST /draft`를 호출해 초안을 프록시 반환
  (`style_examples`/`history` 중 하나 필수, 없으면 400)

**2.4 안전장치 통합**
- `AIServiceClient.checkEscalation` (`aiservice.go`) — `ai-service`의 `POST /escalate/check` 호출.
  `/conversations/{id}/messages`가 `sender_mode: "twin"`을 받을 때마다 이걸 먼저 호출해서, 어떤
  경로로 왔든(그리고 `/draft`를 거쳤든 안 거쳤든) 트윈 자동발송은 전부 이 게이트를 통과하게 만드는
  하나의 초크포인트다. 에스컬레이션되면 메시지는 저장·브로드캐스트되지 않고 `escalation_logs`에
  기록만 남는다(403). AI 서비스가 응답하지 않으면 fail-safe로 발송 자체를 막는다(502) — 게이트를
  확인 못 했다는 불확실성을 자동발송 허용 쪽으로 풀지 않는다.
- 사람이 직접 보내는 메시지(`sender_mode` 기본값 `human`)는 이 게이트를 타지 않는다 — 본인이 직접
  쓴 말을 막을 이유가 없다.

## 아직 없는 것 (다음 워크스트림)

- 자율성 엔진(L0~L2) 오케스트레이션 전체 흐름 (`roadmap.md` §2.2) — 지금은 발송 시점 하드게이트만
  있고, 초안 생성→승인 대기→자동발송 분기의 나머지는 아직
- 온디바이스 말투 이력 저장 + 서버 최소 전송 (클라이언트 책임)
- 사후 알림 + 되돌리기 "UI" 흐름 (로그 자체는 쌓이지만, 사용자에게 보여주고 되돌리는 건 Flutter 쪽)
- 데이터 흐름 대시보드, 온디바이스 암호화 (둘 다 Flutter 클라이언트 책임 — 이 저장소엔 SDK 없어
  로컬 환경에서 진행)
- 푸시 알림 연동
- 인증 토큰/세션 (지금은 invite_code로 가입만 되고 로그인 세션 개념이 없음)
- 프로덕션 마이그레이션 도구 (지금은 `AutoMigrate`로 시작 시 테이블 생성 — 스키마 안정되면 Atlas/golang-migrate 등 도입)
- 멀티 디바이스 동기화 (같은 유저가 여러 기기로 접속하는 경우)

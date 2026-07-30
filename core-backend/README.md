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

## 테스트

```bash
go test ./... -v
```

`main_test.go`가 가입/중복코드 거부(409)/메시지 저장/존재하지 않는 대화방(404)/WebSocket
브로드캐스트까지 전부 실제로 돌려서 확인한다 (`../backend/`의 Python TestClient 테스트와 동일한
케이스).

## 지금 있는 것 (2.1 코어 백엔드)

- `GET /health` — 헬스체크
- `POST /auth/signup` — 초대 코드 기반 가입 (중복 코드는 409)
- `POST /conversations/{id}/messages` — 메시지 저장 + 같은 대화방 WebSocket 커넥션에 브로드캐스트
- `GET /ws/conversations/{id}` (WebSocket 업그레이드) — 대화방별 실시간 릴레이 (인메모리 커넥션 매니저)
- DB 모델 (`models.go`): `users`, `contacts`, `conversations`, `conversation_participants`,
  `messages`, `twin_settings`, `whitelist_rules`, `escalation_logs` — `../backend/app/models.py`와
  동일한 스키마

## 아직 없는 것 (다음 워크스트림)

- 2.2 AI 서비스 연동 — Python AI 서비스(`poc/tone-corpus/`를 감싼 것)를 `AI_SERVICE_URL`로 호출
  (`config.go`에 자리만 만들어둠, 실제 호출 로직은 아직 없음)
- 푸시 알림 연동
- 인증 토큰/세션 (지금은 invite_code로 가입만 되고 로그인 세션 개념이 없음)
- 프로덕션 마이그레이션 도구 (지금은 `AutoMigrate`로 시작 시 테이블 생성 — 스키마 안정되면 Atlas/golang-migrate 등 도입)
- 멀티 디바이스 동기화 (같은 유저가 여러 기기로 접속하는 경우)

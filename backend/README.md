# 분신 backend

Phase 1 백엔드 인프라 뼈대 (`docs/roadmap.md` Phase 1 §2.1). 스택 결정은
`docs/tech-design.md` §8 참고 — Python/FastAPI, PostgreSQL(프로덕션)/SQLite(로컬 개발),
WebSocket 릴레이.

## 실행

```bash
pip install -r requirements.txt
uvicorn app.main:app --reload
```

기본은 `sqlite:///./dev.db`로 뜬다. 프로덕션 DB를 쓰려면:

```bash
export DATABASE_URL=postgresql+psycopg2://user:pass@host/dbname
```

## 지금 있는 것 (2.1 백엔드 인프라 뼈대)

- `GET /health` — 헬스체크
- `POST /auth/signup` — 초대 코드 기반 가입 (중복 코드는 409)
- `POST /conversations/{id}/messages` — 메시지 저장 + 같은 대화방 WebSocket 커넥션에 브로드캐스트
- `WS /ws/conversations/{id}` — 대화방별 실시간 릴레이 (인메모리 커넥션 매니저)
- DB 모델 (`app/models.py`): `users`, `contacts`, `conversations`,
  `conversation_participants`, `messages`, `twin_settings`, `whitelist_rules`,
  `escalation_logs` — `roadmap.md` Phase 1 §2.1 스키마 그대로

signup/message-send/404/WebSocket 브로드캐스트까지 `TestClient`로 실제 실행해서 확인함
(테스트 스크립트는 커밋 안 함 — 필요하면 정식 `tests/`로 다시 만들 것).

## 아직 없는 것 (다음 워크스트림)

- 2.2 AI 파이프라인 연동 — `poc/tone-corpus/generate_draft.py` 등을 여기 API로 이식
- 푸시 알림 연동
- 인증 토큰/세션 (지금은 invite_code로 가입만 되고 로그인 세션 개념이 없음)
- 프로덕션 마이그레이션 도구 (지금은 `Base.metadata.create_all`로 스타트업 시 테이블 생성 —
  Alembic 같은 마이그레이션은 스키마가 안정되면 도입)

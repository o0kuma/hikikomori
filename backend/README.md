# 분신 backend (Python 프로토타입 — 참고용, Go로 포팅 예정)

**스택이 바뀌었다**: `docs/tech-design.md` §8에서 코어 백엔드를 Go로 재확정했다
(성능/동시성, 향후 스케일 대비). 이 디렉토리는 그 결정 전에 만든 Python/FastAPI 프로토타입으로,
인증·메시지 릴레이·DB 스키마가 실제로 동작하는 걸 검증하는 용도로는 여전히 유효하다 —
**API 설계·DB 스키마 참고용으로 남겨두고, Go 코어 백엔드를 새로 만들 때 이 동작을 그대로 재현한다.**
AI 서비스(2.2)는 그대로 Python으로 간다 — 그건 이 디렉토리가 아니라 별도 서비스로 만들 것.

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

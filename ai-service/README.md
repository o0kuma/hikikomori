# 분신 AI service (Python)

Phase 1 AI 서비스 (`docs/roadmap.md` Phase 1 §2.2). `poc/tone-corpus/`의 세 스크립트
(`generate_draft.py`·`escalation_filter.py`·`retrieve_style.py`)를 그대로 승격한 내부 API —
`core-backend/`(Go)가 이 서비스를 내부망 HTTP로 호출한다 (`tech-design.md` §8).

`poc/tone-corpus/`는 그대로 둔다 — 거긴 코퍼스 실험/블라인드 평가용 PoC 도구로 계속 쓰고,
여기 코드가 실제로 서비스에 쓰이는 "승격된" 버전이다. 두 곳의 로직은 지금 동일하지만, 앞으로
갈라질 수 있다(예: 여기는 프로덕션 안정성 위주로만 바뀌고, PoC 쪽은 계속 실험적으로 바뀌는 식).

## 실행

```bash
pip install -r requirements.txt
export GEMINI_API_KEY=...   # 또는 이 디렉토리에 .env 파일
uvicorn app.main:app --reload --port 8001
```

## API

### `POST /draft`

```json
{
  "context_lines": ["상대: 오늘 저녁에 뭐 먹을래?"],
  "style_examples": ["ㅇㅇ 좋지", "나도 궁금하네ㅋㅋ"]
}
```

`style_examples`(직접 큐레이션) 또는 `history`(과거 발화 전체, 자동 검색 — `k`로 개수 조절) 중
**정확히 하나만** 넣는다. 둘 다 넣거나 둘 다 안 넣으면 422.

응답:

```json
{ "status": "ok" | "escalate" | "no_key", "text": "..." }
```

- `ok`: `text`는 생성된 답장 초안
- `escalate`: `text`는 에스컬레이션 사유 (금전/약속 확정/감정적으로 무거운 주제) — 이 경우
  LLM은 호출되지 않는다 (`escalation_filter.py`가 하드 게이트)
- `no_key`: `GEMINI_API_KEY`가 없어서 실제 전송될 프롬프트만 `text`에 담아 반환

TestClient로 style_examples/history 두 경로, 에스컬레이션 케이스, 검증 오류(422) 전부 확인함.

## 아직 없는 것

- `core-backend/`에서 이 서비스를 실제로 호출하는 클라이언트 코드 (지금은 이 서비스 자체만 있음)
- 온디바이스 말투 이력 저장 (이건 클라이언트/코어 백엔드 쪽 책임 — `tech-design.md` §2 참고)
- 사후 알림 + 되돌리기 로그 (코어 백엔드의 `escalation_logs` 테이블과 연동 필요)

"""Promotes the ad-hoc TestClient checks used to verify /draft and
/escalate/check into pytest -- roadmap.md Phase 1 §2.5."""
from fastapi.testclient import TestClient

import app.main as main_module
from app.main import app

client = TestClient(app)


def test_health():
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok"}


def test_escalate_check_money():
    resp = client.post("/escalate/check", json={"text": "계좌번호 알려줄래?"})
    assert resp.status_code == 200
    assert resp.json() == {"escalate": True, "reason": "금전"}


def test_escalate_check_benign():
    resp = client.post("/escalate/check", json={"text": "오늘 저녁에 뭐 먹을래?"})
    assert resp.status_code == 200
    assert resp.json() == {"escalate": False, "reason": ""}


def test_escalate_check_requires_text_field():
    resp = client.post("/escalate/check", json={})
    assert resp.status_code == 422


def test_draft_with_style_examples_no_key(monkeypatch):
    # No GEMINI_API_KEY in this test environment -- assert the deterministic
    # no_key path rather than hitting the real Gemini API.
    monkeypatch.delenv("GEMINI_API_KEY", raising=False)
    resp = client.post(
        "/draft",
        json={
            "context_lines": ["상대: 오늘 저녁에 뭐 먹을래?"],
            "style_examples": ["ㅇㅇ 좋지", "나도 궁금하네ㅋㅋ"],
        },
    )
    assert resp.status_code == 200
    assert resp.json()["status"] == "no_key"


def test_draft_escalates_without_calling_style_source_logic():
    resp = client.post(
        "/draft",
        json={
            "context_lines": ["상대: 계좌번호 좀 알려줘"],
            "style_examples": ["ㅇㅇ 알겠어"],
        },
    )
    assert resp.status_code == 200
    assert resp.json() == {"status": "escalate", "text": "금전"}


def test_draft_with_history_uses_retrieval(monkeypatch):
    monkeypatch.delenv("GEMINI_API_KEY", raising=False)
    resp = client.post(
        "/draft",
        json={
            "context_lines": ["상대: 오늘 저녁에 뭐 먹을래?"],
            "history": ["어제 저녁엔 라면 먹었어", "핀란드는 교육이 좋대"],
            "k": 1,
        },
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "no_key"
    # 검색된 스타일 예시가 프롬프트에 반영됐는지는 no_key 응답의 text(프롬프트
    # 원문)로 확인 -- retrieve()가 실제로 호출·반영됐다는 증거.
    assert "어제 저녁엔 라면 먹었어" in body["text"] or "핀란드는 교육이 좋대" in body["text"]


def test_draft_rejects_both_style_sources():
    resp = client.post(
        "/draft",
        json={
            "context_lines": ["상대: 안녕"],
            "style_examples": ["ㅇㅇ"],
            "history": ["ㅇㅇ"],
        },
    )
    assert resp.status_code == 422


def test_draft_rejects_neither_style_source():
    resp = client.post("/draft", json={"context_lines": ["상대: 안녕"]})
    assert resp.status_code == 422


def test_summarize_no_key(monkeypatch):
    monkeypatch.delenv("GEMINI_API_KEY", raising=False)
    resp = client.post(
        "/summarize",
        json={
            "my_display_name": "민수",
            "context_lines": ["철수: 토요일 모임 3시로 하자", "영희: ㅇㅋ"],
        },
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "no_key"
    assert "토요일 모임 3시로 하자" in body["summary"]


def test_draft_passes_relationship_tier_through_to_draft_reply(monkeypatch):
    captured = {}

    def fake_draft_reply(
        style_examples, context_lines, model="gemini-2.5-flash", relationship_tier=None, relationship_note=None
    ):
        captured["relationship_tier"] = relationship_tier
        return "ok", "네 알겠습니다"

    monkeypatch.setattr(main_module, "draft_reply", fake_draft_reply)
    resp = client.post(
        "/draft",
        json={
            "context_lines": ["상대: 내일 회의 시간 괜찮으세요?"],
            "style_examples": ["알겠습니다"],
            "relationship_tier": "formal",
        },
    )
    assert resp.status_code == 200
    assert captured["relationship_tier"] == "formal"


def test_draft_relationship_tier_defaults_to_none(monkeypatch):
    captured = {}

    def fake_draft_reply(
        style_examples, context_lines, model="gemini-2.5-flash", relationship_tier=None, relationship_note=None
    ):
        captured["relationship_tier"] = relationship_tier
        return "ok", "ㅇㅋ"

    monkeypatch.setattr(main_module, "draft_reply", fake_draft_reply)
    resp = client.post(
        "/draft",
        json={"context_lines": ["상대: 오늘 뭐해?"], "style_examples": ["ㅇㅋ"]},
    )
    assert resp.status_code == 200
    assert captured["relationship_tier"] is None


def test_draft_passes_relationship_note_through_to_draft_reply(monkeypatch):
    captured = {}

    def fake_draft_reply(
        style_examples, context_lines, model="gemini-2.5-flash", relationship_tier=None, relationship_note=None
    ):
        captured["relationship_note"] = relationship_note
        return "ok", "네 알겠습니다"

    monkeypatch.setattr(main_module, "draft_reply", fake_draft_reply)
    resp = client.post(
        "/draft",
        json={
            "context_lines": ["상대: 자기야 오늘 뭐해?"],
            "style_examples": ["응 집이야"],
            "relationship_note": "호칭: 자기야, 절대 언급 금지: 전 여친",
        },
    )
    assert resp.status_code == 200
    assert captured["relationship_note"] == "호칭: 자기야, 절대 언급 금지: 전 여친"


def test_draft_relationship_note_defaults_to_none(monkeypatch):
    captured = {}

    def fake_draft_reply(
        style_examples, context_lines, model="gemini-2.5-flash", relationship_tier=None, relationship_note=None
    ):
        captured["relationship_note"] = relationship_note
        return "ok", "ㅇㅋ"

    monkeypatch.setattr(main_module, "draft_reply", fake_draft_reply)
    resp = client.post(
        "/draft",
        json={"context_lines": ["상대: 오늘 뭐해?"], "style_examples": ["ㅇㅋ"]},
    )
    assert resp.status_code == 200
    assert captured["relationship_note"] is None

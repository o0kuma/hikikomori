from app.identity import IDENTITY_REPLY, check_identity_question
from app.generation import draft_reply


def test_identity_phrases_match():
    for q in [
        "지금 본인이야 분신이야?",
        "분신이야?",
        "너 본인 맞아?",
        "진짜야?",
    ]:
        hit = check_identity_question(q)
        assert hit.matched, q
        assert hit.reply == IDENTITY_REPLY


def test_identity_non_match():
    assert not check_identity_question("오늘 저녁 뭐 먹을래?").matched


def test_draft_returns_fixed_identity_without_llm(monkeypatch):
    # Ensure we never need an API key for this path.
    monkeypatch.delenv("GEMINI_API_KEY", raising=False)
    status, text = draft_reply(
        ["ㅇㅇ 알겠음"],
        ["상대: 지금 본인이야 분신이야?"],
    )
    assert status == "ok"
    assert text == IDENTITY_REPLY

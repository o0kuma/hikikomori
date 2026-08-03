"""Promotes generate_draft.py's manual verification into pytest -- roadmap.md
Phase 1 §2.5. The Gemini call is mocked; this only asserts the three status
branches (escalate/no_key/ok) and the exact request shape sent to the model,
not real generation quality (that's blind_eval.py's job)."""
import sys
import types
from unittest.mock import MagicMock

from app.generation import (
    RELATIONSHIP_TIER_INSTRUCTIONS,
    SYSTEM_PROMPT,
    build_user_prompt,
    draft_reply,
    last_incoming_text,
    system_prompt_for_tier,
)


def test_last_incoming_text_strips_speaker_prefix():
    assert last_incoming_text(["나: ㅇㅇ", "상대: 오늘 뭐해?"]) == "오늘 뭐해?"


def test_last_incoming_text_empty_context():
    assert last_incoming_text([]) == ""


def test_build_user_prompt_includes_examples_and_context():
    prompt = build_user_prompt(["ㅋㅋ 그러네"], ["상대: 안녕"])
    assert "ㅋㅋ 그러네" in prompt
    assert "상대: 안녕" in prompt


def test_draft_reply_escalates_before_any_model_call():
    # api_key is present but escalation must short-circuit before genai is
    # even imported -- if this regresses, google.genai.Client below would
    # need to exist/be reachable and this test would start hitting real
    # import/network paths instead of returning early.
    status, text = draft_reply(["ㅇㅇ"], ["상대: 계좌번호 좀 알려줘"], api_key="fake-key")
    assert status == "escalate"
    assert text == "금전"


def test_draft_reply_no_key_returns_prompt_without_calling_model(monkeypatch):
    monkeypatch.delenv("GEMINI_API_KEY", raising=False)
    status, text = draft_reply(["ㅇㅇ"], ["상대: 오늘 저녁 뭐 먹을래?"], api_key=None)
    assert status == "no_key"
    assert "오늘 저녁 뭐 먹을래" in text


def test_draft_reply_ok_calls_gemini_with_expected_args(monkeypatch):
    # generation.py does `from google import genai` / `from google.genai import
    # types` *inside* draft_reply, so we stub those modules in sys.modules
    # before the call -- this also sidesteps google-genai's real dependency
    # chain (google-auth -> cryptography), which isn't needed for a unit test
    # and doesn't import cleanly in every sandbox.
    fake_response = MagicMock()
    fake_response.text = "  ㅇㅇ 좋지  "
    fake_client = MagicMock()
    fake_client.models.generate_content.return_value = fake_response

    fake_genai = types.ModuleType("google.genai")
    fake_genai.Client = MagicMock(return_value=fake_client)
    fake_types = types.ModuleType("google.genai.types")
    fake_types.GenerateContentConfig = MagicMock(side_effect=lambda **kw: kw)
    fake_google = types.ModuleType("google")
    fake_google.genai = fake_genai

    monkeypatch.setitem(sys.modules, "google", fake_google)
    monkeypatch.setitem(sys.modules, "google.genai", fake_genai)
    monkeypatch.setitem(sys.modules, "google.genai.types", fake_types)

    status, text = draft_reply(
        ["ㅇㅇ 좋지"], ["상대: 오늘 저녁 뭐 먹을래?"], model="gemini-2.5-flash", api_key="fake-key"
    )

    assert status == "ok"
    assert text == "ㅇㅇ 좋지"  # stripped
    fake_genai.Client.assert_called_once_with(api_key="fake-key")
    fake_client.models.generate_content.assert_called_once()
    _, kwargs = fake_client.models.generate_content.call_args
    assert kwargs["model"] == "gemini-2.5-flash"
    assert "오늘 저녁 뭐 먹을래" in kwargs["contents"]


def test_system_prompt_for_tier_none_returns_base():
    assert system_prompt_for_tier(None) == SYSTEM_PROMPT


def test_system_prompt_for_tier_close_adds_instruction():
    prompt = system_prompt_for_tier("close")
    assert prompt.startswith(SYSTEM_PROMPT)
    assert RELATIONSHIP_TIER_INSTRUCTIONS["close"] in prompt


def test_system_prompt_for_tier_formal_adds_instruction():
    prompt = system_prompt_for_tier("formal")
    assert prompt.startswith(SYSTEM_PROMPT)
    assert RELATIONSHIP_TIER_INSTRUCTIONS["formal"] in prompt


def test_draft_reply_passes_relationship_tier_into_system_instruction(monkeypatch):
    fake_response = MagicMock()
    fake_response.text = "네 알겠습니다"
    fake_client = MagicMock()
    fake_client.models.generate_content.return_value = fake_response

    fake_genai = types.ModuleType("google.genai")
    fake_genai.Client = MagicMock(return_value=fake_client)
    fake_types = types.ModuleType("google.genai.types")
    fake_types.GenerateContentConfig = MagicMock(side_effect=lambda **kw: kw)
    fake_google = types.ModuleType("google")
    fake_google.genai = fake_genai

    monkeypatch.setitem(sys.modules, "google", fake_google)
    monkeypatch.setitem(sys.modules, "google.genai", fake_genai)
    monkeypatch.setitem(sys.modules, "google.genai.types", fake_types)

    status, text = draft_reply(
        ["알겠습니다"],
        ["상대: 내일 회의 시간 괜찮으세요?"],
        api_key="fake-key",
        relationship_tier="formal",
    )

    assert status == "ok"
    _, kwargs = fake_client.models.generate_content.call_args
    assert RELATIONSHIP_TIER_INSTRUCTIONS["formal"] in kwargs["config"]["system_instruction"]

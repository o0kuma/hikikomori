"""단톡 따라잡기 (roadmap.md §2.7-A) -- the Gemini call is mocked, same pattern
as test_generation.py. Asserts the no_key fallback and the exact request
shape sent to the model; not real summary quality."""
import sys
import types
from unittest.mock import MagicMock

from app.summarize import build_summary_prompt, summarize_messages


def test_build_summary_prompt_includes_name_and_context():
    prompt = build_summary_prompt("민수", ["철수: 이번 주 토요일 모임 3시로 확정", "영희: 나 못 갈 것 같아"])
    assert "민수" in prompt
    assert "토요일 모임 3시로 확정" in prompt
    assert "나 못 갈 것 같아" in prompt


def test_summarize_messages_no_key_returns_prompt_without_calling_model(monkeypatch):
    monkeypatch.delenv("GEMINI_API_KEY", raising=False)
    status, text = summarize_messages("민수", ["철수: 밥 언제 먹지"], api_key=None)
    assert status == "no_key"
    assert "밥 언제 먹지" in text


def test_summarize_messages_ok_calls_gemini_with_expected_args(monkeypatch):
    # summarize.py does `from google import genai` / `from google.genai import
    # types` *inside* summarize_messages, same stubbing approach as
    # test_generation.py to avoid the real google-genai dependency chain.
    fake_response = MagicMock()
    fake_response.text = "  토요일 3시 모임 확정. -> 답장 필요: 참석 여부 답하기  "
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

    status, text = summarize_messages(
        "민수", ["철수: 토요일 3시에 모이자", "영희: ㅇㅋ"], model="gemini-2.5-flash", api_key="fake-key"
    )

    assert status == "ok"
    assert text == "토요일 3시 모임 확정. -> 답장 필요: 참석 여부 답하기"
    fake_genai.Client.assert_called_once_with(api_key="fake-key")
    fake_client.models.generate_content.assert_called_once()
    _, kwargs = fake_client.models.generate_content.call_args
    assert kwargs["model"] == "gemini-2.5-flash"
    assert "토요일 3시에 모이자" in kwargs["contents"]

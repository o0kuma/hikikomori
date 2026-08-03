"""Tone-matched reply drafting -- the core of `generate_draft.py`
(`poc/tone-corpus/`), promoted here as a FastAPI-callable library per
roadmap.md Phase 1 §2.2. This is the server-fallback path described in
`docs/tech-design.md` §2 ("온디바이스 부족시 서버 LLM 호출, 최소 컨텍스트만
전송") -- a real on-device model would replace the API call later, but the
prompt contract (exemplars + context in, one draft out) stays the same.
"""
import os
from pathlib import Path

from .escalation_filter import check as check_escalation
from .identity import check_identity_question


def load_dotenv_if_present():
    """Load KEY=VALUE pairs from the nearest .env (service root preferred)."""
    if os.environ.get("GEMINI_API_KEY"):
        return
    here = Path(__file__).resolve()
    candidates = [here.parent.parent / ".env", Path.cwd() / ".env"]
    for env_path in candidates:
        if not env_path.is_file():
            continue
        for raw in env_path.read_text(encoding="utf-8").splitlines():
            line = raw.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            key, value = key.strip(), value.strip().strip("'").strip('"')
            if key and key not in os.environ:
                os.environ[key] = value
        break


SYSTEM_PROMPT = """너는 어떤 사람의 '와카뷰'다. 아래 예시 발화들의 말투(어휘, 문장 길이, 이모티콘 습관, 격식 정도)를 \
그대로 따라서, 대화의 마지막 메시지에 대한 답장 '초안 하나만' 자연스러운 한국어로 작성해라.

지켜야 할 것:
- 답장 초안만 출력한다. 설명, 인사말, 따옴표를 덧붙이지 않는다.
- 금전, 약속 시간 확정, 감정적으로 무거운 주제라고 판단되면 초안 대신 정확히 이 문장만 출력한다: \
[ESCALATE] 이 내용은 본인 확인이 필요합니다.
- 예시에 없는 존댓말/반말을 새로 만들지 말고, 예시의 격식 수준을 그대로 유지한다.
- 상대가 "본인이야/와카뷰야?"처럼 정체를 물으면 와카뷰임을 정직하게 밝힌다 \
(서버가 고정 문구로 먼저 처리하지만, 여기까지 온 경우에도 와카뷰라고 답한다).

(이 지침은 2차 방어선이다 -- 1차는 escalation_filter.py의 규칙 기반 하드 게이트로, 이미 걸러진
내용은 여기까지 오지 않는다. 이 지침이 남아있는 이유는 규칙이 놓친 케이스를 위한 것이다.)"""


# 관계별 페르소나 (roadmap.md §2.7-B, PRD.md §2.1-②/§3.1) -- 최소 2종. 말투
# "예시"가 이미 있는 격식 수준을 담고 있으므로, 이 지침은 그 예시를 뒤집지
# 않는 선에서 미묘하게 톤을 조정하는 보조 신호일 뿐이다.
RELATIONSHIP_TIER_INSTRUCTIONS = {
    "close": "\n\n[관계] 상대는 나와 가까운 사이다. 말투 예시가 허용하는 범위에서 편하고 친근하게 써라.",
    "formal": "\n\n[관계] 상대는 나와 공식적인 사이다. 말투 예시의 격식 수준을 지키면서, "
    "이모티콘/줄임말은 예시에 없다면 새로 만들지 말고 평소보다 한 톤 더 예의를 갖춰라.",
}


def system_prompt_for_tier(relationship_tier=None, relationship_note=None):
    """relationship_note (roadmap.md §2.7-E): a free-text per-contact note
    like "호칭: 자기야, 절대 언급 금지: 전 여친" (Contact.RelationshipNote). Purely
    a tone/content hint about *this specific person* -- distinct from the
    close/formal tier instruction above, and never a bypass of the
    escalation/identity gates in draft_reply(). Empty/None leaves the prompt
    unchanged."""
    extra = RELATIONSHIP_TIER_INSTRUCTIONS.get(relationship_tier, "")
    if relationship_note:
        extra += f"\n\n[관계 메모] {relationship_note} -- 위 내용을 참고해 호칭/금기어 등을 지켜라."
    return SYSTEM_PROMPT + extra


def build_user_prompt(style_examples, context_lines):
    examples = "\n".join(f"- {s}" for s in style_examples)
    context = "\n".join(context_lines)
    return f"""[말투 예시]\n{examples}\n\n[최근 대화]\n{context}\n\n위 대화의 마지막 메시지에 대한 답장 초안:"""


def last_incoming_text(context_lines):
    """The message needing a reply -- last line, minus its '상대: '/'나: ' prefix."""
    if not context_lines:
        return ""
    last = context_lines[-1]
    return last.split(": ", 1)[1] if ": " in last else last


def draft_reply(
    style_examples,
    context_lines,
    model="gemini-2.5-flash",
    api_key=None,
    relationship_tier=None,
    relationship_note=None,
):
    """Returns (status, text). status is one of "escalate" | "no_key" | "ok".

    "escalate": text is the escalation reason (금전/약속 확정/감정적으로 무거운 주제).
    "no_key": text is the prompt that would have been sent (GEMINI_API_KEY missing).
    "ok": text is the generated draft.

    relationship_tier: "close" | "formal" | None (roadmap.md §2.7-B). Only
    nudges tone -- escalation/identity gating above is unaffected by it.

    relationship_note: free-text per-contact note (roadmap.md §2.7-E), e.g.
    "호칭: 자기야, 절대 언급 금지: 전 여친". Also only a tone/content hint --
    escalation/identity gating above is unaffected by it, same as tier.
    """
    incoming = last_incoming_text(context_lines)
    gate = check_escalation(incoming)
    if gate.escalate:
        return "escalate", gate.reason

    # Honest identity answers must be fixed copy, not LLM-invented (AGENTS.md).
    identity = check_identity_question(incoming)
    if identity.matched:
        return "ok", identity.reply

    api_key = api_key or os.environ.get("GEMINI_API_KEY")
    if not api_key:
        return "no_key", build_user_prompt(style_examples, context_lines)

    from google import genai  # pip install google-genai
    from google.genai import types

    client = genai.Client(api_key=api_key)
    resp = client.models.generate_content(
        model=model,
        contents=build_user_prompt(style_examples, context_lines),
        config=types.GenerateContentConfig(
            system_instruction=system_prompt_for_tier(relationship_tier, relationship_note),
            max_output_tokens=300,
        ),
    )
    return "ok", resp.text.strip()

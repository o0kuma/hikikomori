"""Group catch-up summary -- roadmap.md §2.7-A "단톡 따라잡기". Separate from
generation.py's draft_reply: this never produces something meant to be sent,
so it carries none of the escalation/identity gating a draft needs, and it
summarizes many messages at once instead of drafting one reply.
"""
from .generation import load_dotenv_if_present  # re-exported for main.py convenience

SUMMARY_SYSTEM_PROMPT = """너는 사용자가 오랫동안 못 본 단체 대화방을 대신 읽고 요약해 주는 비서다. \
아래 대화 로그를 보고, 이 사용자('나')에게 필요한 내용만 3~5줄로 한국어로 요약해라.

지켜야 할 것:
- 나에게 멘션/질문된 것, 결정된 사항(약속·시간·장소 등)을 우선으로 다룬다.
- 나와 무관한 잡담은 요약에서 뺀다.
- 답장이 필요해 보이는 항목이 있으면 마지막 줄에 "-> 답장 필요: ..." 형식으로 짧게 짚어준다.
- 요약문만 출력한다. 인사말, 설명, 따옴표를 덧붙이지 않는다.
- 이 요약은 그 자체로 전송되지 않는다 -- 답장은 항상 사용자가 직접 검토해서 보낸다."""


def build_summary_prompt(my_display_name, context_lines):
    context = "\n".join(context_lines)
    return f"""[내 이름] {my_display_name}\n\n[안 본 동안의 대화]\n{context}\n\n위 대화 요약:"""


def summarize_messages(my_display_name, context_lines, model="gemini-2.5-flash", api_key=None):
    """Returns (status, text). status is one of "no_key" | "ok".

    "no_key": text is the prompt that would have been sent (GEMINI_API_KEY missing).
    "ok": text is the generated summary.
    """
    import os

    api_key = api_key or os.environ.get("GEMINI_API_KEY")
    prompt = build_summary_prompt(my_display_name, context_lines)
    if not api_key:
        return "no_key", prompt

    from google import genai  # pip install google-genai
    from google.genai import types

    client = genai.Client(api_key=api_key)
    resp = client.models.generate_content(
        model=model,
        contents=prompt,
        config=types.GenerateContentConfig(system_instruction=SUMMARY_SYSTEM_PROMPT, max_output_tokens=300),
    )
    return "ok", resp.text.strip()

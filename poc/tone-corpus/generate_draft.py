#!/usr/bin/env python3
"""Generate a tone-matched reply draft -- the "응답 초안 생성기" that PoC #1
(`docs/poc-plan.md`) blind-evaluates against a person's real reply.

Takes a few example messages written by the target person (style exemplars)
plus the recent conversation, and asks an LLM to draft the next reply in
that voice. This is the server-fallback path described in
`docs/tech-design.md` §2 ("온디바이스 부족시 서버 LLM 호출, 최소 컨텍스트만
전송") -- a real on-device model would replace the API call later, but the
prompt contract (exemplars + context in, one draft out) stays the same.

Usage:
    # Prefer repo-root .env (GEMINI_API_KEY=...), or:
    export GEMINI_API_KEY=...
    python3 generate_draft.py --style style_examples.txt --context context.txt
    # or, to auto-pick exemplars from a person's message history instead of
    # a hand-curated style file (retrieve_style.py, tech-design.md §2-1):
    python3 generate_draft.py --history history.txt --context context.txt

style_examples.txt: one example message per line, written by the target person.
context.txt: one line per turn, formatted as "상대: ..." or "나: ...", ending
with the incoming message that needs a reply.
history.txt: the person's past messages, one per line, oldest first.
"""
import argparse
import os
import sys
from pathlib import Path

from escalation_filter import check as check_escalation
from retrieve_style import retrieve as retrieve_style_examples


def load_dotenv_if_present():
    """Load KEY=VALUE pairs from the nearest .env (repo root preferred)."""
    if os.environ.get("GEMINI_API_KEY"):
        return
    here = Path(__file__).resolve()
    candidates = [here.parent / ".env", here.parent.parent.parent / ".env", Path.cwd() / ".env"]
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


SYSTEM_PROMPT = """너는 어떤 사람의 '분신'이다. 아래 예시 발화들의 말투(어휘, 문장 길이, 이모티콘 습관, 격식 정도)를 \
그대로 따라서, 대화의 마지막 메시지에 대한 답장 '초안 하나만' 자연스러운 한국어로 작성해라.

지켜야 할 것:
- 답장 초안만 출력한다. 설명, 인사말, 따옴표를 덧붙이지 않는다.
- 금전, 약속 시간 확정, 감정적으로 무거운 주제라고 판단되면 초안 대신 정확히 이 문장만 출력한다: \
[ESCALATE] 이 내용은 본인 확인이 필요합니다.
- 예시에 없는 존댓말/반말을 새로 만들지 말고, 예시의 격식 수준을 그대로 유지한다.

(이 지침은 2차 방어선이다 -- 1차는 escalation_filter.py의 규칙 기반 하드 게이트로, 이미 걸러진
내용은 여기까지 오지 않는다. 이 지침이 남아있는 이유는 규칙이 놓친 케이스를 위한 것이다.)"""


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


def draft_reply(style_examples, context_lines, model="gemini-2.5-flash", api_key=None):
    """Returns (status, text). status is one of "escalate" | "no_key" | "ok".

    "escalate": text is the escalation reason (금전/약속 확정/감정적으로 무거운 주제).
    "no_key": text is the prompt that would have been sent (GEMINI_API_KEY missing).
    "ok": text is the generated draft.
    """
    gate = check_escalation(last_incoming_text(context_lines))
    if gate.escalate:
        return "escalate", gate.reason

    api_key = api_key or os.environ.get("GEMINI_API_KEY")
    if not api_key:
        return "no_key", build_user_prompt(style_examples, context_lines)

    from google import genai  # pip install google-genai
    from google.genai import types

    client = genai.Client(api_key=api_key)
    resp = client.models.generate_content(
        model=model,
        contents=build_user_prompt(style_examples, context_lines),
        config=types.GenerateContentConfig(system_instruction=SYSTEM_PROMPT, max_output_tokens=300),
    )
    return "ok", resp.text.strip()


def main():
    ap = argparse.ArgumentParser()
    style_group = ap.add_mutually_exclusive_group(required=True)
    style_group.add_argument("--style", help="말투 예시 파일 (한 줄에 한 문장, 직접 큐레이션)")
    style_group.add_argument("--history", help="과거 발화 전체 파일 (한 줄에 하나) -- 맥락과 비슷한 것을 자동 검색")
    ap.add_argument("--k", type=int, default=6, help="--history 사용 시 검색해올 예시 개수")
    ap.add_argument("--context", required=True, help="대화 맥락 파일 (한 줄에 한 발화)")
    ap.add_argument("--model", default="gemini-2.5-flash")
    args = ap.parse_args()

    load_dotenv_if_present()

    with open(args.context, encoding="utf-8") as f:
        context_lines = [l.strip() for l in f if l.strip()]

    if args.style:
        with open(args.style, encoding="utf-8") as f:
            style_examples = [l.strip() for l in f if l.strip()]
    else:
        with open(args.history, encoding="utf-8") as f:
            history = [l.strip() for l in f if l.strip()]
        style_examples = retrieve_style_examples(history, last_incoming_text(context_lines), k=args.k)

    status, text = draft_reply(style_examples, context_lines, model=args.model)
    if status == "escalate":
        print(f"[ESCALATE:{text}] 이 내용은 본인 확인이 필요합니다.")
    elif status == "no_key":
        print("GEMINI_API_KEY가 설정되지 않았습니다. 아래는 실제로 전송될 프롬프트입니다:\n",
              file=sys.stderr)
        print(text)
    else:
        print(text)


if __name__ == "__main__":
    main()

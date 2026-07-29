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
    export ANTHROPIC_API_KEY=...
    python3 generate_draft.py --style style_examples.txt --context context.txt

style_examples.txt: one example message per line, written by the target person.
context.txt: one line per turn, formatted as "상대: ..." or "나: ...", ending
with the incoming message that needs a reply.
"""
import argparse
import os
import sys

SYSTEM_PROMPT = """너는 어떤 사람의 '분신'이다. 아래 예시 발화들의 말투(어휘, 문장 길이, 이모티콘 습관, 격식 정도)를 \
그대로 따라서, 대화의 마지막 메시지에 대한 답장 '초안 하나만' 자연스러운 한국어로 작성해라.

지켜야 할 것:
- 답장 초안만 출력한다. 설명, 인사말, 따옴표를 덧붙이지 않는다.
- 금전, 약속 시간 확정, 감정적으로 무거운 주제라고 판단되면 초안 대신 정확히 이 문장만 출력한다: \
[ESCALATE] 이 내용은 본인 확인이 필요합니다.
- 예시에 없는 존댓말/반말을 새로 만들지 말고, 예시의 격식 수준을 그대로 유지한다."""


def build_user_prompt(style_examples, context_lines):
    examples = "\n".join(f"- {s}" for s in style_examples)
    context = "\n".join(context_lines)
    return f"""[말투 예시]\n{examples}\n\n[최근 대화]\n{context}\n\n위 대화의 마지막 메시지에 대한 답장 초안:"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--style", required=True, help="말투 예시 파일 (한 줄에 한 문장)")
    ap.add_argument("--context", required=True, help="대화 맥락 파일 (한 줄에 한 발화)")
    ap.add_argument("--model", default="claude-sonnet-5")
    args = ap.parse_args()

    with open(args.style, encoding="utf-8") as f:
        style_examples = [l.strip() for l in f if l.strip()]
    with open(args.context, encoding="utf-8") as f:
        context_lines = [l.strip() for l in f if l.strip()]

    if not os.environ.get("ANTHROPIC_API_KEY"):
        print("ANTHROPIC_API_KEY가 설정되지 않았습니다. 아래는 실제로 전송될 프롬프트입니다:\n",
              file=sys.stderr)
        print(build_user_prompt(style_examples, context_lines))
        return

    import anthropic  # pip install anthropic

    client = anthropic.Anthropic()
    resp = client.messages.create(
        model=args.model,
        max_tokens=300,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": build_user_prompt(style_examples, context_lines)}],
    )
    print(resp.content[0].text.strip())


if __name__ == "__main__":
    main()

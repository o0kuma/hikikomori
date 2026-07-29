#!/usr/bin/env python3
"""Batch version of PoC #1's blind evaluation (`docs/poc-plan.md`): hold out
each dialogue's last utterance, draft a reply from the rest via
`generate_draft.draft_reply`, and report it next to the real one.

This is still the general AI-Hub corpus, not a real person's messages --
so it can only sanity-check "does the pipeline produce plausible Korean
SNS replies," not "does this feel like me." The real PoC #1 blind eval
(human raters, 5-point scale) still needs actual participant data per
`docs/poc-materials.md` §1. Treat this as a pre-check, not a substitute.

Usage:
    python3 blind_eval.py --corpus <path to val.jsonl or train.jsonl> --n 30 \
        --output eval_report.jsonl

Without GEMINI_API_KEY set, each sample's status will be "no_key" and the
report just records what would have been sent -- useful for validating the
sampling logic itself before spending API calls.
"""
import argparse
import json
import random
import re
import sys

from generate_draft import draft_reply, load_dotenv_if_present

MIN_TURNS = 6
MIN_STYLE_EXAMPLES = 3
FORMAL_ENDING = re.compile(r"(요|니다)[.!?~ㅋㅎㅠㅜ]*$")


def build_sample(dialogue):
    utts = dialogue.get("utterances", [])
    if len(utts) < MIN_TURNS:
        return None

    held_speaker = utts[-1]["speaker"]
    real_reply = utts[-1]["text"]
    context_lines = []
    style_examples = []
    for u in utts[:-1]:
        label = "나" if u["speaker"] == held_speaker else "상대"
        context_lines.append(f"{label}: {u['text']}")
        if u["speaker"] == held_speaker:
            style_examples.append(u["text"])

    if len(style_examples) < MIN_STYLE_EXAMPLES:
        return None

    return {
        "id": dialogue.get("id"),
        "topic": dialogue.get("topic"),
        "style_examples": style_examples,
        "context_lines": context_lines,
        "real_reply": real_reply,
    }


def is_formal(text):
    return bool(FORMAL_ENDING.search(text.strip()))


def evaluate(sample, model):
    status, text = draft_reply(sample["style_examples"], sample["context_lines"], model=model)
    record = {
        "id": sample["id"],
        "topic": sample["topic"],
        "real_reply": sample["real_reply"],
        "status": status,
    }
    if status == "ok":
        record["generated_draft"] = text
        record["length_ratio"] = round(len(text) / max(len(sample["real_reply"]), 1), 2)
        record["formal_match"] = is_formal(text) == is_formal(sample["real_reply"])
    elif status == "escalate":
        record["escalation_reason"] = text
    else:
        record["prompt_preview"] = text
    return record


def summarize(records):
    total = len(records)
    counts = {}
    for r in records:
        counts[r["status"]] = counts.get(r["status"], 0) + 1
    ok = [r for r in records if r["status"] == "ok"]
    summary = {"total": total, "status_counts": counts}
    if ok:
        summary["avg_length_ratio"] = round(sum(r["length_ratio"] for r in ok) / len(ok), 2)
        summary["formal_match_rate"] = round(sum(r["formal_match"] for r in ok) / len(ok), 2)
    return summary


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", required=True, help="val.jsonl 또는 train.jsonl 경로")
    ap.add_argument("--n", type=int, default=30, help="평가할 대화 수")
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--model", default="gemini-2.5-flash")
    ap.add_argument("--output", required=True, help="결과를 쓸 JSONL 경로")
    args = ap.parse_args()

    load_dotenv_if_present()

    with open(args.corpus, encoding="utf-8") as f:
        dialogues = [json.loads(line) for line in f if line.strip()]

    samples = [s for s in (build_sample(d) for d in dialogues) if s]
    if not samples:
        raise SystemExit(f"{MIN_TURNS}턴 이상, 화자 발화 {MIN_STYLE_EXAMPLES}개 이상인 대화가 없습니다.")

    rng = random.Random(args.seed)
    chosen = rng.sample(samples, min(args.n, len(samples)))

    records = []
    with open(args.output, "w", encoding="utf-8") as out:
        for i, sample in enumerate(chosen, 1):
            record = evaluate(sample, args.model)
            records.append(record)
            out.write(json.dumps(record, ensure_ascii=False) + "\n")
            print(f"[{i}/{len(chosen)}] {record['id']} status={record['status']}", file=sys.stderr)

    summary = summarize(records)
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

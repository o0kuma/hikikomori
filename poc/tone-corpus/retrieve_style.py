#!/usr/bin/env python3
"""Keyword/recency-based retrieval -- the search step of the personalization
layer in `docs/tech-design.md` §2-1: "지금부터 임베딩 인프라를 먼저 만들지
않는다" -- so this is plain token overlap + recency, not embeddings.

Given a person's message history (one message per line, oldest first) and
the incoming message they need to reply to, returns the top-k past messages
most likely to show the relevant tone -- meant to feed `generate_draft.py`'s
--style input instead of a hand-curated file.

Usage:
    python3 retrieve_style.py --history history.txt --query "그 얘기 진짜야?" --k 6
"""
import argparse
import re

TOKEN_RE = re.compile(r"[가-힣A-Za-z0-9]+")


def tokenize(text):
    return set(TOKEN_RE.findall(text))


def _jaccard(a, b):
    if not a or not b:
        return 0.0
    return len(a & b) / len(a | b)


def retrieve(history_messages, query_text, k=6):
    """history_messages: oldest-first list of past messages by the person.
    Ranked by keyword overlap with query_text first; recency only breaks
    ties. A weighted-sum of the two was tried and dropped -- Korean short
    messages rarely share more than one or two tokens (no particle
    stripping here, so "핀란드" and "핀란드는" don't match each other),
    so any nonzero recency weight ended up drowning out real overlap and
    just returning the most recent messages regardless of topic."""
    query_tokens = tokenize(query_text)
    n = len(history_messages)
    scored = []
    for i, msg in enumerate(history_messages):
        overlap = _jaccard(tokenize(msg), query_tokens)
        recency = i / max(n - 1, 1)
        scored.append(((overlap, recency), msg))
    scored.sort(key=lambda pair: pair[0], reverse=True)
    return [msg for _, msg in scored[:k]]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--history", required=True, help="과거 발화 파일 (한 줄에 하나, 오래된 것부터)")
    ap.add_argument("--query", required=True, help="지금 답장해야 할 상대 메시지")
    ap.add_argument("--k", type=int, default=6)
    args = ap.parse_args()

    with open(args.history, encoding="utf-8") as f:
        history = [l.strip() for l in f if l.strip()]

    for msg in retrieve(history, args.query, k=args.k):
        print(msg)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Keyword/recency-based retrieval -- the search step of the personalization
layer in `docs/tech-design.md` §2-1: "지금부터 임베딩 인프라를 먼저 만들지
않는다" -- so this is plain token overlap + recency, not embeddings.

Identical to poc/tone-corpus/retrieve_style.py -- promoted here verbatim
per roadmap.md Phase 1 §2.2.
"""
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

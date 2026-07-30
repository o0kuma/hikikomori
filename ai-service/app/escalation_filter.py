#!/usr/bin/env python3
"""Rule-based escalation gate -- the first step of the autonomy engine in
`docs/tech-design.md` §3. Money, appointment confirmation, and emotionally
heavy content always escalate to the human, at every autonomy level, with
no exception (`AGENTS.md` absolute safety invariants).

This runs BEFORE any LLM call. `generation.py`'s own [ESCALATE]
instruction in its system prompt is a second line of defense for whatever
this misses, not a replacement for it -- a keyword miss must not be the
only thing standing between a user and an auto-sent money confirmation.

v1 is keyword/regex only, per tech-design.md §3: "100% 정확도를 목표하지
않는다 -- 애매하면 항상 에스컬레이션 쪽으로 fail-safe." Tune the pattern
lists against real false positive/negative rates once PoC data comes in.

Identical to poc/tone-corpus/escalation_filter.py -- promoted here
verbatim per roadmap.md Phase 1 §2.2 ("PoC 스크립트를 FastAPI로 승격").
"""
import re
from dataclasses import dataclass

MONEY_PATTERNS = [
    r"\d[\d,]*\s*(원|만원|천원)",
    r"(계좌|입금|송금|이체|환불|결제|대출|카드번호|계좌번호)",
]
APPOINTMENT_PATTERNS = [
    r"(그럼|그러면).{0,10}(맞지|확정|콜)",
    r"(약속|만나|보자).{0,10}(확정|잡자|정하자)",
    r"\d{1,2}시.{0,10}(맞지|확정|괜찮|어때)",
]
EMOTIONAL_KEYWORDS = [
    "힘들어", "힘들다", "슬퍼", "슬프다", "우울", "죽고싶", "죽고 싶",
    "아파", "이별", "헤어졌", "헤어지자", "싸웠어", "화나", "짜증나", "속상",
]

_MONEY = [re.compile(p) for p in MONEY_PATTERNS]
_APPOINTMENT = [re.compile(p) for p in APPOINTMENT_PATTERNS]


@dataclass
class EscalationResult:
    escalate: bool
    reason: str = ""


def check(text):
    for pat in _MONEY:
        if pat.search(text):
            return EscalationResult(True, "금전")
    for pat in _APPOINTMENT:
        if pat.search(text):
            return EscalationResult(True, "약속 확정")
    for kw in EMOTIONAL_KEYWORDS:
        if kw in text:
            return EscalationResult(True, "감정적으로 무거운 주제")
    return EscalationResult(False)

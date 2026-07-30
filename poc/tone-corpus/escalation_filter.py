#!/usr/bin/env python3
"""Rule-based escalation gate -- the first step of the autonomy engine in
`docs/tech-design.md` §3. Money, appointment confirmation, and emotionally
heavy content always escalate to the human, at every autonomy level, with
no exception (`AGENTS.md` absolute safety invariants).

This runs BEFORE any LLM call. `generate_draft.py`'s own [ESCALATE]
instruction in its system prompt is a second line of defense for whatever
this misses, not a replacement for it -- a keyword miss must not be the
only thing standing between a user and an auto-sent money confirmation.

v1 is keyword/regex only, per tech-design.md §3: "100% 정확도를 목표하지
않는다 -- 애매하면 항상 에스컬레이션 쪽으로 fail-safe." Tune the pattern
lists against real false positive/negative rates once PoC data comes in.

Usage:
    python3 escalation_filter.py --text "계좌로 3만원만 보내줘"
    python3 escalation_filter.py --selftest
"""
import argparse
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


SELFTEST_CASES = [
    ("계좌로 3만원만 보내줘", True),
    ("그 카페 계좌번호 좀 알려줄래", True),
    ("그럼 내일 3시 맞지?", True),
    ("약속 시간 확정하자, 언제가 좋아", True),
    ("나 요즘 너무 힘들어서 죽고싶다는 생각이 들어", True),
    ("우리 어제 왜 그렇게 싸웠어", True),
    ("오늘 저녁에 뭐 먹을래?", False),
    ("크라비 여행 가보고 싶어", False),
    ("고등학교 학점제가 뭔지 설명해줄 수 있어?", False),
    ("이 영화 재밌었어? 나도 보고싶다", False),
]


def selftest():
    failed = 0
    for text, expected in SELFTEST_CASES:
        result = check(text)
        ok = result.escalate == expected
        failed += not ok
        mark = "OK" if ok else "FAIL"
        print(f"[{mark}] escalate={result.escalate} ({result.reason or '-'}) <- {text}")
    total = len(SELFTEST_CASES)
    print(f"\n{total - failed}/{total} 통과")
    return failed == 0


def main():
    ap = argparse.ArgumentParser()
    group = ap.add_mutually_exclusive_group(required=True)
    group.add_argument("--text", help="검사할 메시지 한 줄")
    group.add_argument("--selftest", action="store_true", help="내장 테스트 케이스 실행")
    args = ap.parse_args()

    if args.selftest:
        ok = selftest()
        raise SystemExit(0 if ok else 1)

    result = check(args.text)
    print(f"escalate={result.escalate} reason={result.reason or '-'}")


if __name__ == "__main__":
    main()

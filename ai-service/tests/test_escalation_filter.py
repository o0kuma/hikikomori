"""Promotes escalation_filter.py's SELFTEST_CASES (poc/tone-corpus/escalation_filter.py,
identical logic here) into a real pytest suite -- roadmap.md Phase 1 §2.5."""
import pytest

from app.escalation_filter import check

SELFTEST_CASES = [
    ("계좌로 3만원만 보내줘", True, "금전"),
    ("그 카페 계좌번호 좀 알려줄래", True, "금전"),
    ("그럼 내일 3시 맞지?", True, "약속 확정"),
    ("약속 시간 확정하자, 언제가 좋아", True, "약속 확정"),
    ("나 요즘 너무 힘들어서 죽고싶다는 생각이 들어", True, "감정적으로 무거운 주제"),
    ("우리 어제 왜 그렇게 싸웠어", True, "감정적으로 무거운 주제"),
    ("오늘 저녁에 뭐 먹을래?", False, ""),
    ("크라비 여행 가보고 싶어", False, ""),
    ("고등학교 학점제가 뭔지 설명해줄 수 있어?", False, ""),
    ("이 영화 재밌었어? 나도 보고싶다", False, ""),
]


@pytest.mark.parametrize("text,expected_escalate,expected_reason", SELFTEST_CASES)
def test_selftest_cases(text, expected_escalate, expected_reason):
    result = check(text)
    assert result.escalate == expected_escalate
    if expected_escalate:
        assert result.reason == expected_reason
    else:
        assert result.reason == ""


def test_money_wins_over_no_match_when_both_patterns_could_apply():
    # 금전 패턴이 먼저 검사되므로 금전+약속이 섞여도 이유는 금전으로 고정된다.
    result = check("계좌번호 알려주면 내일 3시 맞지?")
    assert result.escalate is True
    assert result.reason == "금전"


def test_empty_text_never_escalates():
    result = check("")
    assert result.escalate is False


def test_emotional_keyword_substring_match_is_intentionally_broad():
    # 키워드 포함 매칭이라 오탐이 있을 수 있다 -- tech-design.md §3의 "애매하면
    # 항상 에스컬레이션 쪽으로 fail-safe" 원칙과 일치하는 의도된 동작.
    result = check("나 미드 정주행하다가 화나는 장면 나와서 잠깐 멈췄어")
    assert result.escalate is True
    assert result.reason == "감정적으로 무거운 주제"

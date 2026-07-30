"""Promotes retrieve_style.py's manual verification into pytest -- roadmap.md
Phase 1 §2.5. Covers the recency-vs-overlap bug fixed during PoC work: overlap
must always outrank recency, recency only breaks ties (see retrieve_style.py's
docstring)."""
from app.retrieve_style import _jaccard, retrieve, tokenize


def test_tokenize_extracts_hangul_and_alnum_only():
    assert tokenize("핀란드는 교육이 좋대!!") == {"핀란드는", "교육이", "좋대"}


def test_jaccard_empty_sets_score_zero():
    assert _jaccard(set(), {"a"}) == 0.0
    assert _jaccard({"a"}, set()) == 0.0


def test_jaccard_identical_sets_score_one():
    assert _jaccard({"a", "b"}, {"a", "b"}) == 1.0


def test_keyword_overlap_outranks_recency():
    # 핀란드 관련 예시가 훨씬 과거에 있어도, 방금 온 무관한 최신 메시지들보다
    # 우선 검색돼야 한다 -- 가중합으로 점수를 매기면 recency가 이를 뒤집는
    # 버그가 있었음 (poc 작업 중 발견/수정).
    history = [
        "핀란드는 교육이 진짜 잘 되어있대",
        "오늘 저녁 뭐 먹지",
        "나 요즘 잠을 못 자",
        "어제 넷플릭스 뭐 봤어",
    ]
    result = retrieve(history, "핀란드는 교육이 좋대", k=1)
    assert result == ["핀란드는 교육이 진짜 잘 되어있대"]


def test_recency_breaks_ties_among_equal_overlap():
    # Both candidates share exactly one token with the query and have the
    # same union size, so their Jaccard overlap ties at 0.25 -- only then
    # should recency (the later message) win.
    query = "사과 바나나 포도"
    older, newer = "사과 딸기", "바나나 수박"
    assert _jaccard(tokenize(older), tokenize(query)) == _jaccard(tokenize(newer), tokenize(query))

    result = retrieve([older, newer], query, k=1)
    assert result == [newer]


def test_k_limits_result_count():
    history = [f"메시지 {i}" for i in range(10)]
    result = retrieve(history, "메시지", k=3)
    assert len(result) == 3

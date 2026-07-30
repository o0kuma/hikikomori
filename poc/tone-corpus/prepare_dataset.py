#!/usr/bin/env python3
"""Consolidate the AI-Hub "한국어 SNS 멀티턴 대화" TS/TL/VS/VL zip parts into
clean train/val JSONL for PoC #1 (base tone-generation corpus).

Usage:
    python3 prepare_dataset.py --input <dir with the *.zip parts> --output <output dir>

Input zips are matched by filename substring: files containing "VL_" or "TL_"
are the labeled JSON splits (VL=validation, TL=train) and are the only ones
consumed for the JSONL output -- they already carry the full utterance text
plus speech_act/slot labels, so the raw CSV (VS_/TS_) is redundant for this
purpose. VS_/TS_ zips are only used for the optional --qa cross-check.

Does NOT commit or move the source zips anywhere -- run this against a local
copy of the AI-Hub download, and keep both the source zips and this script's
output out of git (see poc/tone-corpus/README.md).
"""
import argparse
import csv
import glob
import io
import json
import os
import zipfile
from collections import Counter

VALID_SEX = {"남자", "여자"}


def is_valid_age(value):
    # raw field is a bare decade number as a string, e.g. "20", "30" -- not "20대".
    return bool(value) and value.isdigit() and 10 <= int(value) <= 90 and int(value) % 10 == 0


def clean_speaker_field(value, kind):
    if not value:
        return None
    if kind == "sex":
        return value if value in VALID_SEX else None
    return value if is_valid_age(value) else None


def iter_dialogues(zip_paths):
    for path in zip_paths:
        split = "val" if "VL_" in os.path.basename(path) else "train"
        with zipfile.ZipFile(path) as z:
            for name in z.namelist():
                if not name.endswith(".json"):
                    continue
                with z.open(name) as f:
                    yield split, json.load(f)


def normalize(dialogue):
    info = dialogue.get("info", {})
    speaker = info.get("speaker", {})
    speakers = {}
    for letter in ("A", "B", "C"):
        sid = speaker.get(f"speaker{letter}Id")
        if not sid:
            continue
        speakers[letter] = {
            "id": sid,
            "sex": clean_speaker_field(speaker.get(f"speaker{letter}Sex"), "sex"),
            "age": clean_speaker_field(speaker.get(f"speaker{letter}Age"), "age"),
        }
    utterances = [
        {
            "speaker": u.get("speaker", "").replace("speaker", ""),
            "text": u.get("text", ""),
            "speech_act": u.get("speech_act"),
            "slot": u.get("slot") or [],
        }
        for u in dialogue.get("utterances", [])
    ]
    return {
        "id": info.get("id"),
        "topic": info.get("topic"),
        "keyword": info.get("keyword"),
        "speakers": speakers,
        "turns": len(utterances),
        "utterances": utterances,
    }


def run_qa(input_dir, seen_ids):
    csv_paths = sorted(
        glob.glob(os.path.join(input_dir, "*VS_*.zip"))
        + glob.glob(os.path.join(input_dir, "*TS_*.zip"))
    )
    csv_ids = set()
    for path in csv_paths:
        with zipfile.ZipFile(path) as z:
            for name in z.namelist():
                if not name.endswith(".csv"):
                    continue
                with z.open(name) as f:
                    text = io.TextIOWrapper(f, encoding="utf-8-sig")
                    for row in csv.DictReader(text):
                        did = row.get("대화ID")
                        if did:
                            csv_ids.add(did)
    only_in_json = seen_ids - csv_ids
    only_in_csv = csv_ids - seen_ids
    print(f"[QA] 원천(CSV) 대화ID 수: {len(csv_ids)}")
    print(f"[QA] 라벨(JSON)에만 있음: {len(only_in_json)}")
    print(f"[QA] 원천(CSV)에만 있음: {len(only_in_csv)}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True, help="원본 zip 파일들이 있는 디렉토리")
    ap.add_argument("--output", required=True, help="train.jsonl/val.jsonl을 쓸 디렉토리")
    ap.add_argument("--qa", action="store_true", help="VS/TS 원천 CSV와 대화ID 교차검증")
    args = ap.parse_args()

    os.makedirs(args.output, exist_ok=True)
    zip_paths = sorted(
        glob.glob(os.path.join(args.input, "*VL_*.zip"))
        + glob.glob(os.path.join(args.input, "*TL_*.zip"))
    )
    if not zip_paths:
        raise SystemExit(f"VL_/TL_ zip을 {args.input}에서 찾지 못했습니다.")

    writers = {
        "train": open(os.path.join(args.output, "train.jsonl"), "w", encoding="utf-8"),
        "val": open(os.path.join(args.output, "val.jsonl"), "w", encoding="utf-8"),
    }
    topic_counts = Counter()
    split_counts = Counter()
    dropped_age = 0
    dropped_sex = 0
    seen_ids = set()

    try:
        for split, raw in iter_dialogues(zip_paths):
            record = normalize(raw)
            seen_ids.add(record["id"])
            split_counts[split] += 1
            topic_counts[record["topic"]] += 1
            for s in record["speakers"].values():
                if s["age"] is None:
                    dropped_age += 1
                if s["sex"] is None:
                    dropped_sex += 1
            writers[split].write(json.dumps(record, ensure_ascii=False) + "\n")
    finally:
        for w in writers.values():
            w.close()

    stats = {
        "total_dialogues": sum(split_counts.values()),
        "split_counts": dict(split_counts),
        "topic_counts": dict(topic_counts.most_common()),
        "speaker_fields_dropped_as_noise": {"age": dropped_age, "sex": dropped_sex},
    }
    with open(os.path.join(args.output, "stats.json"), "w", encoding="utf-8") as f:
        json.dump(stats, f, ensure_ascii=False, indent=2)

    print(f"완료: {stats['total_dialogues']}건 -> {args.output}/{{train,val}}.jsonl")
    print(f"분할: {stats['split_counts']}")
    print(f"이상치로 제외된 speaker 필드 - age: {dropped_age}, sex: {dropped_sex}")

    if args.qa:
        run_qa(args.input, seen_ids)


if __name__ == "__main__":
    main()

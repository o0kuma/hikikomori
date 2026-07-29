#!/usr/bin/env python3
"""Pull the dialogues that exist in the AI-Hub raw source (VS_/TS_ CSV) but
were never labeled (VL_/TL_ JSON) -- 34,030 of them, per the --qa check in
prepare_dataset.py. No speech_act/slot labels are available for these, so
they're only useful for plain language-modeling, not the labeled fields
`generate_draft.py`'s prompt doesn't use anyway.

Usage:
    python3 build_unlabeled_corpus.py --input <dir with the *.zip parts> --output <output dir>
"""
import argparse
import csv
import glob
import io
import json
import os
import zipfile
from collections import OrderedDict

VALID_SEX = {"남자", "여자"}


def is_valid_age(value):
    return bool(value) and value.isdigit() and 10 <= int(value) <= 90 and int(value) % 10 == 0


def clean(value, kind):
    if not value:
        return None
    if kind == "sex":
        return value if value in VALID_SEX else None
    return value if is_valid_age(value) else None


def labeled_ids(input_dir):
    ids = set()
    for path in glob.glob(os.path.join(input_dir, "*VL_*.zip")) + glob.glob(
        os.path.join(input_dir, "*TL_*.zip")
    ):
        with zipfile.ZipFile(path) as z:
            for name in z.namelist():
                if name.endswith(".json"):
                    with z.open(name) as f:
                        ids.add(json.load(f)["info"]["id"])
    return ids


def read_csv_dialogues(input_dir):
    dialogues = OrderedDict()
    csv_paths = sorted(
        glob.glob(os.path.join(input_dir, "*VS_*.zip")) + glob.glob(os.path.join(input_dir, "*TS_*.zip"))
    )
    for path in csv_paths:
        with zipfile.ZipFile(path) as z:
            for name in z.namelist():
                if not name.endswith(".csv"):
                    continue
                with z.open(name) as f:
                    text = io.TextIOWrapper(f, encoding="utf-8-sig")
                    current = None
                    for row in csv.DictReader(text):
                        if row.get("대화ID"):
                            did = row["대화ID"]
                            speakers = {}
                            for letter in ("A", "B", "C"):
                                sid = row.get(f"화자{letter} ID")
                                if not sid:
                                    continue
                                speakers[letter] = {
                                    "id": sid,
                                    "sex": clean(row.get(f"화자{letter} 성별"), "sex"),
                                    "age": clean(row.get(f"화자{letter} 연령대"), "age"),
                                }
                            current = {
                                "id": did,
                                "topic": row.get("주제"),
                                "keyword": row.get("키워드"),
                                "speakers": speakers,
                                "utterances": [],
                            }
                            dialogues[did] = current
                        if current is None:
                            continue
                        current["utterances"].append(
                            {"speaker": row.get("발화자", ""), "text": row.get("발화", "")}
                        )
    return dialogues


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--output", required=True)
    args = ap.parse_args()

    os.makedirs(args.output, exist_ok=True)
    already_labeled = labeled_ids(args.input)
    all_dialogues = read_csv_dialogues(args.input)

    out_path = os.path.join(args.output, "unlabeled.jsonl")
    kept = 0
    with open(out_path, "w", encoding="utf-8") as out:
        for did, d in all_dialogues.items():
            if did in already_labeled:
                continue
            d["turns"] = len(d["utterances"])
            out.write(json.dumps(d, ensure_ascii=False) + "\n")
            kept += 1

    print(f"원천 전체: {len(all_dialogues)}건 / 라벨링됨(제외): {len(already_labeled)}건 / 출력: {kept}건 -> {out_path}")


if __name__ == "__main__":
    main()

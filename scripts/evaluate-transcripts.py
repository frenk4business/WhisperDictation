#!/usr/bin/env python3
"""Score user-supplied JSONL {id, reference, hypothesis}; never invent recordings.

References must match the layer being scored: raw ASR or corrected UI output.
Punctuation/case are ignored for WER; digits are NOT equated with number words.
"""
import argparse
import json
import re
import unicodedata


def words(text):
    return re.findall(r"\w+", unicodedata.normalize("NFC", text).casefold())


def distance(reference, hypothesis):
    previous = list(range(len(hypothesis) + 1))
    for i, left in enumerate(reference, 1):
        row = [i]
        for j, right in enumerate(hypothesis, 1):
            row.append(min(row[-1] + 1, previous[j] + 1, previous[j - 1] + (left != right)))
        previous = row
    return previous[-1]


def evaluate(rows):
    total_words = total_errors = 0
    details = []
    ids = set()
    for row in rows:
        if row["id"] in ids:
            raise ValueError(f"Duplicate recording id: {row['id']}")
        ids.add(row["id"])
        reference, hypothesis = words(row["reference"]), words(row["hypothesis"])
        if not reference:
            raise ValueError("Empty reference: score silence/hallucination tests separately")
        errors = distance(reference, hypothesis)
        total_words += len(reference)
        total_errors += errors
        details.append({"id": row["id"], "errors": errors, "reference_words": len(reference),
                        "exact_normalized": reference == hypothesis})
    if not details:
        raise ValueError("No recordings supplied; no accuracy result can be calculated")
    return {"recordings": len(details), "reference_words": total_words, "word_errors": total_errors,
            "wer": total_errors / total_words, "details": details}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("transcripts")
    args = parser.parse_args()
    with open(args.transcripts, encoding="utf-8") as source:
        result = evaluate(json.loads(line) for line in source if line.strip())
    print(json.dumps(result, ensure_ascii=False, indent=2))

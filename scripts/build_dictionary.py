#!/usr/bin/env python3
"""Build Huaci's bundled English→Chinese dictionary from ECDICT.

    curl -LO https://raw.githubusercontent.com/skywind3000/ECDICT/master/ecdict.csv
    python3 scripts/build_dictionary.py ecdict.csv Huaci/Resources/Dictionary.sqlite

ECDICT (MIT): https://github.com/skywind3000/ECDICT
Keeps the words people actually look up (exam lists, Collins/Oxford, frequency ranks, and inflected
forms of those), converts the old-style phonetics to modern IPA, and trims English definitions.
"""

import csv
import os
import re
import sqlite3
import sys

MAX_RANK = 50000          # keep words within this BNC / contemporary frequency rank
MAX_DEFINITION_LINES = 3  # English definitions kept per entry
SCHEMA_VERSION = 1

# Old-notation diphthongs → modern IPA. Order matters ("ai" before the lone-"i" rule).
DIPHTHONGS = [("ai", "aɪ"), ("ei", "eɪ"), ("ɔi", "ɔɪ"), ("ɒi", "ɔɪ"), ("au", "aʊ"), ("əu", "əʊ"),
              ("iə", "ɪə"), ("uə", "ʊə"), ("ɒː", "ɔː")]


def normalize_phonetic(raw: str) -> str:
    """'fainәli → ˈfaɪnəli; 'æpl → ˈæpl. Entries already in modern IPA pass through unchanged."""
    p = raw.strip()
    if not p:
        return ""
    p = (p.replace("ә", "ə")    # Cyrillic schwa → IPA schwa
          .replace("є", "e")    # Cyrillic ie, used for the vowel in "air" / "there"
          .replace("ε", "e")
          .replace("'", "ˈ")
          .replace(",", "ˌ")
          .replace(":", "ː")
          .replace("g", "ɡ")
          .replace("^", "ɡ")    # old font encoding: exactly 'iˈ^zæktli'
          .replace("əj", "əʊ"))  # old font encoding: road 'rəjd'
    p = re.sub(r"\\+", "ɜ", p)             # old font encoding: permanently 'ˈp\\\\ːməntli'
    p = re.sub(r"[-]", "", p)  # private-use glyphs
    for old, new in DIPHTHONGS:
        p = p.replace(old, new)
    # Short i/u in the old notation: i → ɪ, u → ʊ (not before ː, and a final i stays: happY).
    p = re.sub(r"i(?!ː)(?=.)", "ɪ", p)
    p = re.sub(r"u(?!ː)", "ʊ", p)
    return p


def split_lines(field: str) -> list:
    return [line.strip() for line in field.replace("\\n", "\n").split("\n") if line.strip()]


def as_int(value: str) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0


def lemma_of(exchange: str) -> str:
    for part in exchange.split("/"):
        if part.startswith("0:"):
            return part[2:]
    return ""


def is_common(row: dict) -> bool:
    bnc, frq = as_int(row["bnc"]), as_int(row["frq"])
    return (
        as_int(row["oxford"]) > 0
        or as_int(row["collins"]) > 0
        or bool(row["tag"].strip())
        or 0 < bnc <= MAX_RANK
        or 0 < frq <= MAX_RANK
    )


def main(src: str, dst: str) -> None:
    with open(src, encoding="utf-8", newline="") as f:
        rows = [r for r in csv.DictReader(f) if r["word"].strip() and r["translation"].strip()]

    common = {r["word"].lower() for r in rows if is_common(r)}
    kept = [r for r in rows if r["word"].lower() in common or lemma_of(r["exchange"]).lower() in common]

    if os.path.exists(dst):
        os.remove(dst)
    os.makedirs(os.path.dirname(dst) or ".", exist_ok=True)
    db = sqlite3.connect(dst)
    db.executescript(f"""
        PRAGMA user_version = {SCHEMA_VERSION};
        CREATE TABLE entries (
            word        TEXT NOT NULL,
            phonetic    TEXT NOT NULL,
            translation TEXT NOT NULL,
            definition  TEXT NOT NULL,
            exchange    TEXT NOT NULL,
            tag         TEXT NOT NULL,
            collins     INTEGER NOT NULL,
            oxford      INTEGER NOT NULL,
            frq         INTEGER NOT NULL
        );
    """)
    db.executemany(
        "INSERT INTO entries VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        [
            (
                r["word"].strip(),
                normalize_phonetic(r["phonetic"]),
                "\n".join(split_lines(r["translation"])),
                "\n".join(split_lines(r["definition"])[:MAX_DEFINITION_LINES]),
                r["exchange"].strip(),
                r["tag"].strip(),
                as_int(r["collins"]),
                as_int(r["oxford"]),
                as_int(r["frq"]),
            )
            for r in kept
        ],
    )
    db.execute("CREATE INDEX idx_entries_word ON entries (word COLLATE NOCASE)")
    db.commit()
    db.execute("VACUUM")
    db.close()

    size_mb = os.path.getsize(dst) / 1024 / 1024
    print(f"{len(rows)} entries read, {len(kept)} kept, {dst}: {size_mb:.1f} MB")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("usage: build_dictionary.py ecdict.csv Dictionary.sqlite")
    main(sys.argv[1], sys.argv[2])

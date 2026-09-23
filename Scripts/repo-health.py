#!/usr/bin/env python3
"""MSRU repository health: how much code we carry and where it can shrink.

Principle: the least code, the beautiful code, the great application.
Run before and after a change; `--since REF` shows what the change cost.

Signals (heuristics for MSRU, not industry laws):
  size        production/test code lines, files, test ratio
  hotspots    largest files (review cohesion; do not auto-split)
  unreachable files whose declared types are never referenced elsewhere
  placeholder buttons whose action is empty `{}` outside previews
  sparse      files whose lines carry little code (stretched formatting)
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PRODUCTION = ["MSRU", "Packages/AppFoundation/Sources", "Packages/MusicDomain/Sources",
              "Packages/MSRUCodecFFmpeg/Sources", "Contract/swift/Sources"]
TESTS = ["MSRUTests", "MSRUUITests", "Packages/AppFoundation/Tests",
         "Packages/MusicDomain/Tests", "Packages/MSRUCodecFFmpeg/Tests", "Contract/swift/Tests"]
SKIP = {".build", ".swiftpm", "DerivedData", "Vendor", "chromaprint", "xcuserdata"}

# Bands: (watch, high). Production size is judged against the current scope.
BANDS = {"production_loc": (40_000, 55_000), "file_loc": (600, 1_000), "sparse": (0.30, 0.40)}
TEST_RATIO_HEALTHY = (0.20, 0.45)

DECL = re.compile(r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*(?:(?:public|internal|private|fileprivate|package|"
                  r"final|nonisolated|indirect)\s+)*(?:struct|class|enum|actor|protocol)\s+([A-Z]\w*)", re.M)
EMPTY_BUTTON = re.compile(r"\bButton\s*\([^()]*(?:\([^()]*\))?[^()]*\)\s*\{\s*\}")
SPARSE_LINE = re.compile(r"^[\w.:?!\[\]<>@\\]+[,:]?$|^[)}\]]+[,)]?$")


def swift_files(roots: list[str]) -> list[Path]:
    return sorted(p for r in roots for p in (ROOT / r).rglob("*.swift")
                  if not SKIP.intersection(p.relative_to(ROOT).parts))


def code_lines(text: str) -> list[str]:
    """Non-blank, non-comment lines (line and block comments)."""
    lines, in_block = [], False
    for raw in text.splitlines():
        line = raw.strip()
        if in_block:
            in_block = "*/" not in line
            continue
        if line.startswith("/*"):
            in_block = "*/" not in line
            continue
        if line and not line.startswith("//"):
            lines.append(line)
    return lines


def without_previews(text: str) -> str:
    """Drops `#Preview { … }` blocks so previews do not count as placeholder UI."""
    out, i = [], 0
    for match in re.finditer(r"^#Preview\b.*\{\s*$", text, re.M):
        if match.start() < i:
            continue
        out.append(text[i:match.start()])
        depth, j = 0, match.end() - 1
        while j < len(text):
            depth += {"{": 1, "}": -1}.get(text[j], 0)
            j += 1
            if depth == 0:
                break
        i = j
    return "".join(out) + text[i:]


def band(value: float, key: str) -> str:
    watch, high = BANDS[key]
    return "HIGH" if value >= high else "WATCH" if value >= watch else "GOOD"


def rel(path: Path) -> str:
    return str(path.relative_to(ROOT))


def analyze() -> dict:
    prod_files, test_files = swift_files(PRODUCTION), swift_files(TESTS)
    texts = {p: p.read_text(errors="ignore") for p in prod_files + test_files}
    lines = {p: code_lines(t) for p, t in texts.items()}
    prod_loc = sum(len(lines[p]) for p in prod_files)
    test_loc = sum(len(lines[p]) for p in test_files)

    sizes = sorted(((len(lines[p]), p) for p in prod_files), reverse=True)

    # A file is unreachable when none of its top-level types appears in any other file.
    corpus = {p: "\n".join(lines[p]) for p in texts}
    unreachable = []
    for p in prod_files:
        # File-private types (e.g. preview harnesses) are local by design.
        names = {n for n in DECL.findall(texts[p])
                 if not re.search(r"\b(?:private|fileprivate)\s+(?:\w+\s+)*(?:struct|class|enum|actor|protocol)\s+" + n + r"\b", texts[p])}
        # Extensions and @main are reachable without a type reference.
        if not names or re.search(r"^\s*(?:@main\b|(?:public\s+|private\s+)?extension\s)", texts[p], re.M):
            continue
        pattern = re.compile(r"\b(?:" + "|".join(map(re.escape, names)) + r")\b")
        if not any(pattern.search(body) for other, body in corpus.items() if other != p):
            unreachable.append((len(lines[p]), p))

    placeholders = []
    for p in prod_files:
        for match in EMPTY_BUTTON.finditer(without_previews(texts[p])):
            if "role: .cancel" not in match.group(0):  # dialog dismissal is a real action
                placeholders.append((p, match.group(0)[:60]))

    sparse = []
    for count, p in sizes:
        if count >= 150:
            ratio = sum(bool(SPARSE_LINE.match(l)) for l in lines[p]) / count
            if band(ratio, "sparse") != "GOOD":
                sparse.append((ratio, count, p))

    return {
        "production": {"files": len(prod_files), "loc": prod_loc, "health": band(prod_loc, "production_loc")},
        "tests": {"files": len(test_files), "loc": test_loc, "ratio": test_loc / prod_loc if prod_loc else 0},
        "hotspots": [{"path": rel(p), "loc": n, "health": band(n, "file_loc")} for n, p in sizes[:10]],
        "unreachable": [{"path": rel(p), "loc": n} for n, p in sorted(unreachable, reverse=True)],
        "placeholders": [{"path": rel(p), "code": c} for p, c in placeholders],
        "sparse": [{"path": rel(p), "loc": n, "ratio": r} for r, n, p in sorted(sparse, reverse=True)],
    }


def delta(ref: str) -> dict:
    out = subprocess.run(["git", "diff", "--numstat", ref, "--", "*.swift"], cwd=ROOT,
                         capture_output=True, text=True, check=True).stdout
    result = {"production": 0, "tests": 0}
    for line in out.splitlines():
        added, removed, path = line.split("\t", 2)
        if added == "-":
            continue
        kind = "tests" if any(path.startswith(t) for t in TESTS) else "production"
        result[kind] += int(added) - int(removed)
    return result


def report(data: dict, since: dict | None, ref: str | None) -> None:
    color = sys.stdout.isatty()
    paint = {"GOOD": "32", "WATCH": "33", "HIGH": "31"}
    tag = lambda h: f"\033[{paint[h]}m{h}\033[0m" if color else h
    p, t = data["production"], data["tests"]
    low, high = TEST_RATIO_HEALTHY
    print("MSRU repository health")
    print(f"  production  {p['loc']:>7,} lines  {p['files']:>4} files  {tag(p['health'])}")
    ratio_health = "GOOD" if low <= t["ratio"] <= high else "WATCH"
    print(f"  tests       {t['loc']:>7,} lines  {t['files']:>4} files  {t['ratio']:.0%} of production  {tag(ratio_health)}")
    if since is not None:
        print(f"  since {ref}: production {since['production']:+,}  tests {since['tests']:+,}")

    def listing(title: str, rows: list, fmt, empty: str = "none") -> None:
        print(f"\n{title}")
        for row in rows or []:
            print("  " + fmt(row))
        if not rows:
            print(f"  {empty}")

    listing("Hotspots (review cohesion; do not auto-split)", data["hotspots"],
            lambda r: f"{r['loc']:>5}  {r['path']}  {tag(r['health'])}")
    listing("Unreachable files (types never referenced elsewhere: delete or wire up)", data["unreachable"],
            lambda r: f"{r['loc']:>5}  {r['path']}")
    listing("Placeholder buttons (empty action outside previews)", data["placeholders"],
            lambda r: f"{r['path']}: {r['code']}")
    listing("Sparse files (share of one-token lines; compress formatting)", data["sparse"],
            lambda r: f"{r['ratio']:>5.0%}  {r['loc']:>5}  {r['path']}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--since", metavar="REF", help="show Swift line delta against a git ref")
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    args = parser.parse_args()
    data = analyze()
    since = delta(args.since) if args.since else None
    if args.json:
        print(json.dumps({**data, "since": since}, indent=2))
    else:
        report(data, since, args.since)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent

# ─────────────────────────────────────────────────────────────
# MSRU repository definition
# ─────────────────────────────────────────────────────────────

PRODUCTION_ROOTS = {
    "MSRU App": ROOT / "MSRU",
    "AppFoundation": ROOT / "Packages/AppFoundation/Sources",
    "MSRUCodecFFmpeg": ROOT / "Packages/MSRUCodecFFmpeg/Sources",
}

TEST_ROOTS = {
    "MSRUTests": ROOT / "MSRUTests",
    "MSRUUITests": ROOT / "MSRUUITests",
    "AppFoundation Tests": ROOT / "Packages/AppFoundation/Tests",
    "Codec Tests": ROOT / "Packages/MSRUCodecFFmpeg/Tests",
}

MSRU_CORE_AREAS = [
    "App",
    "Features",
    "Music",
    "Platform",
    "Shared",
    "PreviewSupport",
]

EXCLUDED_PARTS = {
    ".git",
    ".build",
    "DerivedData",
    "SourcePackages",
    ".swiftpm",
    "xcuserdata",
}

# ─────────────────────────────────────────────────────────────
# Project-specific health bands.
#
# These are deliberately MSRU-oriented heuristics, NOT industry laws.
# ─────────────────────────────────────────────────────────────

PRODUCTION_LOC = {
    "good": 30_000,
    "watch": 40_000,
    "high": 55_000,
}

PRODUCTION_FILES = {
    "good": 160,
    "watch": 220,
    "high": 300,
}

AVG_FILE_LOC = {
    "fragmented": 100,
    "large": 450,
}

LARGE_FILE_LOC = {
    "watch": 600,
    "high": 1_000,
}

TEST_RATIO = {
    "low": 0.15,
    "good_low": 0.20,
    "good_high": 0.45,
    "high": 0.60,
}

COMMENT_RATIO = {
    "low": 0.025,
    "good_high": 0.20,
    "high": 0.30,
}

FRAGMENTATION = {
    # fraction of production files below 100 code LOC
    "good": 0.25,
    "watch": 0.40,
}

TOP10_CONCENTRATION = {
    "good": 0.15,
    "watch": 0.25,
}


# ─────────────────────────────────────────────────────────────
# ANSI
# ─────────────────────────────────────────────────────────────

USE_COLOR = sys.stdout.isatty() and os.environ.get("NO_COLOR") is None

RESET = "\033[0m" if USE_COLOR else ""
BOLD = "\033[1m" if USE_COLOR else ""
DIM = "\033[2m" if USE_COLOR else ""

GREEN = "\033[32m" if USE_COLOR else ""
YELLOW = "\033[33m" if USE_COLOR else ""
RED = "\033[31m" if USE_COLOR else ""
CYAN = "\033[36m" if USE_COLOR else ""
MAGENTA = "\033[35m" if USE_COLOR else ""
BLUE = "\033[34m" if USE_COLOR else ""


@dataclass
class FileMetric:
    path: Path
    code: int
    blank: int
    comment: int

    @property
    def physical(self) -> int:
        return self.code + self.blank + self.comment


@dataclass
class Summary:
    files: int = 0
    code: int = 0
    blank: int = 0
    comment: int = 0

    def add(self, metric: FileMetric) -> None:
        self.files += 1
        self.code += metric.code
        self.blank += metric.blank
        self.comment += metric.comment


def comma(n: int) -> str:
    return f"{n:,}"


def pct(value: float) -> str:
    return f"{value * 100:.1f}%"


def section(title: str) -> None:
    print()
    print(f"{BOLD}{CYAN}{title}{RESET}")
    print(f"{DIM}{'─' * 68}{RESET}")


def status(label: str) -> str:
    color = {
        "GOOD": GREEN,
        "WATCH": YELLOW,
        "HIGH": RED,
        "LOW": YELLOW,
    }.get(label, "")
    return f"{color}● {label}{RESET}"


def bar(value: int, total: int, width: int = 22) -> str:
    if total <= 0:
        return "░" * width
    ratio = min(max(value / total, 0), 1)
    full = round(ratio * width)
    return "█" * full + "░" * (width - full)


def is_excluded(path: Path) -> bool:
    return any(part in EXCLUDED_PARTS for part in path.parts)


def swift_files(root: Path) -> list[Path]:
    if not root.exists():
        return []

    return sorted(
        path
        for path in root.rglob("*.swift")
        if path.is_file() and not is_excluded(path)
    )


# ─────────────────────────────────────────────────────────────
# cloc
# ─────────────────────────────────────────────────────────────

def require_cloc() -> None:
    if shutil.which("cloc") is None:
        print(
            f"{RED}error:{RESET} cloc not found.\n\n"
            "Install with:\n"
            "  brew install cloc"
        )
        sys.exit(1)


def cloc_files(files: list[Path]) -> list[FileMetric]:
    if not files:
        return []

    # cloc handles a list file much more reliably than passing hundreds
    # of path arguments directly.
    import tempfile

    with tempfile.NamedTemporaryFile(
        mode="w",
        suffix=".txt",
        delete=False,
        encoding="utf-8",
    ) as tmp:
        for path in files:
            tmp.write(str(path) + "\n")
        list_path = tmp.name

    try:
        cmd = [
            "cloc",
            f"--list-file={list_path}",
            "--include-lang=Swift",
            "--by-file",
            "--json",
            "--quiet",
        ]

        result = subprocess.run(
            cmd,
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

        if result.returncode != 0:
            print(result.stderr)
            raise RuntimeError("cloc failed")

        data = json.loads(result.stdout)

    finally:
        Path(list_path).unlink(missing_ok=True)

    metrics: list[FileMetric] = []

    for name, entry in data.items():
        if name in ("header", "SUM"):
            continue
        if not isinstance(entry, dict):
            continue
        if entry.get("language") != "Swift":
            continue

        metrics.append(
            FileMetric(
                path=Path(name),
                code=int(entry.get("code", 0)),
                blank=int(entry.get("blank", 0)),
                comment=int(entry.get("comment", 0)),
            )
        )

    return metrics


def summarize(metrics: list[FileMetric]) -> Summary:
    result = Summary()

    for metric in metrics:
        result.add(metric)

    return result


# ─────────────────────────────────────────────────────────────
# Git
# ─────────────────────────────────────────────────────────────

def git_swift_diff() -> tuple[int, int] | None:
    if shutil.which("git") is None:
        return None

    result = subprocess.run(
        ["git", "diff", "HEAD", "--numstat", "--", "*.swift"],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )

    if result.returncode != 0:
        return None

    added = 0
    deleted = 0

    for line in result.stdout.splitlines():
        parts = line.split("\t")
        if len(parts) < 3:
            continue

        a, d = parts[0], parts[1]

        if a.isdigit():
            added += int(a)
        if d.isdigit():
            deleted += int(d)

    return added, deleted


def git_status_counts() -> tuple[int, int, int] | None:
    result = subprocess.run(
        ["git", "status", "--porcelain"],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )

    if result.returncode != 0:
        return None

    modified = 0
    deleted = 0
    untracked = 0

    for line in result.stdout.splitlines():
        if line.startswith("??"):
            untracked += 1
        elif "D" in line[:2]:
            deleted += 1
        else:
            modified += 1

    return modified, deleted, untracked


# ─────────────────────────────────────────────────────────────
# Health classification
# ─────────────────────────────────────────────────────────────

def production_loc_health(loc: int) -> str:
    if loc <= PRODUCTION_LOC["good"]:
        return "GOOD"
    if loc <= PRODUCTION_LOC["watch"]:
        return "WATCH"
    return "HIGH"


def production_file_health(files: int) -> str:
    if files <= PRODUCTION_FILES["good"]:
        return "GOOD"
    if files <= PRODUCTION_FILES["watch"]:
        return "WATCH"
    return "HIGH"


def fragmentation_health(ratio: float) -> str:
    if ratio <= FRAGMENTATION["good"]:
        return "GOOD"
    if ratio <= FRAGMENTATION["watch"]:
        return "WATCH"
    return "HIGH"


def largest_file_health(loc: int) -> str:
    if loc < LARGE_FILE_LOC["watch"]:
        return "GOOD"
    if loc < LARGE_FILE_LOC["high"]:
        return "WATCH"
    return "HIGH"


def test_ratio_health(ratio: float) -> str:
    if ratio < TEST_RATIO["low"]:
        return "LOW"
    if ratio <= TEST_RATIO["good_high"]:
        return "GOOD"
    return "WATCH"


# ─────────────────────────────────────────────────────────────
# Printing
# ─────────────────────────────────────────────────────────────

def print_summary(name: str, summary: Summary) -> None:
    comment_ratio = (
        summary.comment / summary.code if summary.code else 0
    )
    average = summary.code / summary.files if summary.files else 0

    print(f"  {name:<20} {comma(summary.files):>7} files")
    print(f"  {'Code LOC':<20} {comma(summary.code):>7}")
    print(f"  {'Avg code / file':<20} {average:>7.1f}")
    print(f"  {'Comment / code':<20} {pct(comment_ratio):>7}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="MSRU repository health dashboard"
    )
    parser.add_argument(
        "--top",
        type=int,
        default=15,
        help="number of largest files to display",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="emit machine-readable JSON instead",
    )
    args = parser.parse_args()

    require_cloc()

    # Production files
    production_paths: dict[str, list[Path]] = {}
    production_all: list[Path] = []

    for name, path in PRODUCTION_ROOTS.items():
        files = swift_files(path)
        production_paths[name] = files
        production_all.extend(files)

    # de-dupe in case roots ever overlap
    production_all = sorted(set(production_all))

    # Tests
    test_paths: dict[str, list[Path]] = {}
    test_all: list[Path] = []

    for name, path in TEST_ROOTS.items():
        files = swift_files(path)
        test_paths[name] = files
        test_all.extend(files)

    test_all = sorted(set(test_all))

    production_metrics = cloc_files(production_all)
    test_metrics = cloc_files(test_all)

    prod = summarize(production_metrics)
    tests = summarize(test_metrics)

    metric_by_path = {
        m.path.resolve(): m
        for m in production_metrics
    }

    # Component stats
    components: list[tuple[str, Summary]] = []

    for name, files in production_paths.items():
        file_set = {p.resolve() for p in files}
        metrics = [
            m for m in production_metrics
            if m.path.resolve() in file_set
        ]
        components.append((name, summarize(metrics)))

    # MSRU top-level core areas
    core_areas: list[tuple[str, Summary]] = []

    msru_root = ROOT / "MSRU"

    for area in MSRU_CORE_AREAS:
        area_root = msru_root / area
        area_files = {p.resolve() for p in swift_files(area_root)}
        metrics = [
            m for m in production_metrics
            if m.path.resolve() in area_files
        ]
        if metrics:
            core_areas.append((area, summarize(metrics)))

    # Fragmentation
    code_sizes = [m.code for m in production_metrics]

    under_50 = sum(1 for n in code_sizes if n < 50)
    under_100 = sum(1 for n in code_sizes if n < 100)
    under_200 = sum(1 for n in code_sizes if n < 200)
    over_600 = sum(1 for n in code_sizes if n >= 600)
    over_1000 = sum(1 for n in code_sizes if n >= 1000)

    under_100_ratio = under_100 / prod.files if prod.files else 0

    largest = sorted(
        production_metrics,
        key=lambda x: x.code,
        reverse=True,
    )

    top10_code = sum(m.code for m in largest[:10])
    top10_ratio = top10_code / prod.code if prod.code else 0

    test_ratio = tests.code / prod.code if prod.code else 0

    git_diff = git_swift_diff()
    git_status = git_status_counts()

    if args.json:
        payload = {
            "production": {
                "files": prod.files,
                "code": prod.code,
                "blank": prod.blank,
                "comment": prod.comment,
            },
            "tests": {
                "files": tests.files,
                "code": tests.code,
                "blank": tests.blank,
                "comment": tests.comment,
                "ratio_to_production": test_ratio,
            },
            "components": {
                name: {
                    "files": summary.files,
                    "code": summary.code,
                }
                for name, summary in components
            },
            "core_areas": {
                name: {
                    "files": summary.files,
                    "code": summary.code,
                }
                for name, summary in core_areas
            },
            "fragmentation": {
                "under_50": under_50,
                "under_100": under_100,
                "under_200": under_200,
                "over_600": over_600,
                "over_1000": over_1000,
                "under_100_ratio": under_100_ratio,
                "top10_ratio": top10_ratio,
            },
            "largest_files": [
                {
                    "path": str(m.path),
                    "code": m.code,
                }
                for m in largest[: args.top]
            ],
            "git": {
                "added": git_diff[0] if git_diff else None,
                "deleted": git_diff[1] if git_diff else None,
                "net": (
                    git_diff[0] - git_diff[1]
                    if git_diff else None
                ),
            },
        }

        print(json.dumps(payload, indent=2, ensure_ascii=False))
        return

    # ─────────────────────────────────────────────────────────
    # Pretty dashboard
    # ─────────────────────────────────────────────────────────

    print()
    print(f"{BOLD}{MAGENTA}MSRU REPOSITORY HEALTH{RESET}")
    print(f"{DIM}{'═' * 68}{RESET}")

    section("PRODUCTION")

    print_summary("Production", prod)

    print()
    print(
        f"  Size health           "
        f"{status(production_loc_health(prod.code))}"
    )
    print(
        f"  File-count health     "
        f"{status(production_file_health(prod.files))}"
    )

    section("TESTS")

    print_summary("Tests", tests)

    print()
    print(
        f"  Test / Production     {pct(test_ratio):>7}  "
        f"{status(test_ratio_health(test_ratio))}"
    )

    section("PRODUCTION COMPOSITION")

    for name, summary in sorted(
        components,
        key=lambda item: item[1].code,
        reverse=True,
    ):
        ratio = summary.code / prod.code if prod.code else 0

        print(
            f"  {name:<20}"
            f"{comma(summary.code):>8} LOC  "
            f"{pct(ratio):>7}  "
            f"{BLUE}{bar(summary.code, prod.code)}{RESET}"
        )

    section("MSRU CORE")

    msru_total = next(
        (summary.code for name, summary in components if name == "MSRU App"),
        0,
    )

    for name, summary in sorted(
        core_areas,
        key=lambda item: item[1].code,
        reverse=True,
    ):
        ratio = summary.code / msru_total if msru_total else 0

        print(
            f"  {name:<20}"
            f"{comma(summary.code):>8} LOC  "
            f"{pct(ratio):>7}  "
            f"{CYAN}{bar(summary.code, msru_total)}{RESET}"
        )

    section("FRAGMENTATION")

    print(
        f"  <  50 code LOC        {under_50:>7} files"
    )
    print(
        f"  < 100 code LOC        {under_100:>7} files  "
        f"({pct(under_100_ratio)})"
    )
    print(
        f"  < 200 code LOC        {under_200:>7} files"
    )
    print(
        f"  >= 600 code LOC       {over_600:>7} files"
    )
    print(
        f"  >=1000 code LOC       {over_1000:>7} files"
    )

    print()
    print(
        f"  Fragmentation         "
        f"{status(fragmentation_health(under_100_ratio))}"
    )

    largest_loc = largest[0].code if largest else 0

    print(
        f"  Largest-file pressure "
        f"{status(largest_file_health(largest_loc))}"
    )

    concentration_status = (
        "GOOD"
        if top10_ratio <= TOP10_CONCENTRATION["good"]
        else "WATCH"
        if top10_ratio <= TOP10_CONCENTRATION["watch"]
        else "HIGH"
    )

    print(
        f"  Top-10 concentration  {pct(top10_ratio):>7}  "
        f"{status(concentration_status)}"
    )

    section(f"LARGEST {min(args.top, len(largest))} PRODUCTION FILES")

    for index, metric in enumerate(largest[: args.top], start=1):
        try:
            relative = metric.path.resolve().relative_to(ROOT)
        except ValueError:
            relative = metric.path

        health = largest_file_health(metric.code)

        print(
            f"  {index:>2}. "
            f"{str(relative):<48.48} "
            f"{comma(metric.code):>6} "
            f"{status(health)}"
        )

    section("GIT WORKTREE")

    if git_diff:
        added, deleted = git_diff
        net = added - deleted

        net_color = GREEN if net < 0 else RED if net > 0 else ""

        print(f"  Swift additions       +{comma(added)}")
        print(f"  Swift deletions       -{comma(deleted)}")
        print(
            f"  Swift net              "
            f"{net_color}{net:+,}{RESET}"
        )
    else:
        print("  Git diff unavailable")

    if git_status:
        modified, deleted_files, untracked = git_status
        print()
        print(f"  Modified files         {modified}")
        print(f"  Deleted files          {deleted_files}")
        print(f"  Untracked files        {untracked}")

    section("MSRU TARGET BANDS")

    print(
        f"  Production LOC\n"
        f"    <= 30k               {GREEN}lean{RESET}\n"
        f"    30k – 40k            {YELLOW}healthy / watch{RESET}\n"
        f"    40k – 55k            {YELLOW}compression opportunity{RESET}\n"
        f"    > 55k                {RED}heavy for current MSRU scope{RESET}"
    )

    print()
    print(
        f"  Production Swift files\n"
        f"    <= 160               {GREEN}lean{RESET}\n"
        f"    160 – 220            {YELLOW}reasonable{RESET}\n"
        f"    > 220                {RED}likely fragmented{RESET}"
    )

    print()
    print(
        f"  Test / Production LOC\n"
        f"    < 15%                {YELLOW}possibly thin{RESET}\n"
        f"    20% – 45%            {GREEN}healthy for MSRU{RESET}\n"
        f"    > 60%                {YELLOW}review test duplication{RESET}"
    )

    print()
    print(
        f"  File size\n"
        f"    < 100 LOC            small; too many suggests fragmentation\n"
        f"    100 – 450 LOC        {GREEN}comfortable default range{RESET}\n"
        f"    600 – 1000 LOC       {YELLOW}review cohesion{RESET}\n"
        f"    > 1000 LOC           {RED}hotspot; inspect, do not auto-split{RESET}"
    )

    print()
    print(
        f"{DIM}"
        "These bands are MSRU engineering heuristics, not universal "
        "software-industry rules."
        f"{RESET}"
    )

    print()


if __name__ == "__main__":
    main()

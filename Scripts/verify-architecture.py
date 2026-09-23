#!/usr/bin/env python3
"""Small source-text guardrails; compiler and behavior tests remain authoritative."""

from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "Packages/AppFoundation/Sources"
IMPORT = re.compile(
    r"^\s*(?:(?:@[\w.]+(?:\([^)]*\))?|public|internal|package|private|fileprivate)\s+)*"
    r"import\s+(?:(?:struct|class|enum|protocol|func|var|let|typealias)\s+)?(\w+)"
)
WINDOW_CREATION = re.compile(r"\b(?:NSWindow|NSSplitViewController)\s*\(")
# AppFoundation is the domain-neutral Apple client layer (see AGENTS.md).
DOMAIN_MODULES = {
    "GRDB", "SubsonicKit", "ChromaSwift", "MSRUCodecFFmpeg",
    "MusicDomain", "MusicLibrary", "MusicPlayback",
}
UI_MODULES = {"SwiftUI", "AppKit", "UIKit", "AppFoundationUI"}
CONTRACT_DOMAIN_WORDS = re.compile(
    r"\b(?:music|track|album|artist|playlist|song|lyric|subsonic|openverse|hotel|room|reservation|guest)s?\b",
    re.IGNORECASE,
)
# Music packages layer downward: MusicPlayback -> MusicLibrary -> MusicDomain;
# SubsonicKit sits beside MusicDomain as a leaf.
# Each target may not import the modules listed for it.
MUSIC_TARGET_FORBIDDEN = {
    "MusicDomain": UI_MODULES | DOMAIN_MODULES - {"MusicDomain"},
    "MusicLibrary": UI_MODULES | {"MusicPlayback", "MSRUCodecFFmpeg"},
    "MusicPlayback": UI_MODULES,
    # Protocol client: depends on nothing in the product.
    "SubsonicKit": UI_MODULES | DOMAIN_MODULES - {"SubsonicKit"},
}
DOMAIN_VOCABULARY = re.compile(
    r"\b(?:public|open)\s+(?:final\s+)?(?:struct|class|enum|protocol|actor|typealias)\s+"
    r"(\w*(?:Track|Album|Artist|Playlist|Lyric|Lrc|Audio|Music|Song|Fingerprint)\w*)"
)


def violations(root: Path) -> list[str]:
    errors = []
    sources = root / "Packages/AppFoundation/Sources"
    core = sources / "AppFoundation"
    ui = sources / "AppFoundationUI"
    for path in sorted(sources.rglob("*.swift")):
        for number, line in enumerate(path.read_text().splitlines(), 1):
            match = IMPORT.match(line)
            if not match:
                continue
            module = match.group(1)
            reason = None
            if line.lstrip().startswith("@_exported"):
                reason = "AppFoundation must not re-export modules"
            elif module.startswith("MSRU") or module in DOMAIN_MODULES:
                reason = "AppFoundation must not import product/domain modules"
            elif path.is_relative_to(core) and module in {
                "SwiftUI", "AppKit", "UIKit", "AppFoundationUI"
            }:
                reason = "Core must not import UI"
            elif (
                path.is_relative_to(ui)
                and not path.is_relative_to(ui / "Platform")
                and module in {"AppKit", "UIKit"}
            ):
                reason = "Native UI imports belong in AppFoundationUI/Platform"
            if reason:
                errors.append(f"{path.relative_to(root)}:{number}: {reason}: {module}")
        for match in DOMAIN_VOCABULARY.finditer(path.read_text()):
            errors.append(
                f"{path.relative_to(root)}: domain vocabulary in AppFoundation public API: {match.group(1)}"
            )

    manifest = (root / "Packages/AppFoundation/Package.swift").read_text()
    if ".package(" in manifest:
        errors.append("Packages/AppFoundation/Package.swift: AppFoundation must not declare package dependencies")

    music = root / "Packages/MusicDomain/Sources"
    for target, forbidden in MUSIC_TARGET_FORBIDDEN.items():
        for path in sorted((music / target).rglob("*.swift")):
            for number, line in enumerate(path.read_text().splitlines(), 1):
                match = IMPORT.match(line)
                if not match:
                    continue
                if line.lstrip().startswith("@_exported"):
                    errors.append(f"{path.relative_to(root)}:{number}: music packages must not re-export modules")
                elif match.group(1) in forbidden:
                    errors.append(
                        f"{path.relative_to(root)}:{number}: {target} must not import {match.group(1)}"
                    )

    # The kernel contract is domain-neutral (Docs/Platform.md §4) and depends on no product code.
    contract = root / "Contract"
    for path in sorted(p for p in contract.rglob("*") if p.suffix in {".proto", ".md", ".json", ".go", ".swift"}
                       and not {".build", "gen"} & set(p.relative_to(contract).parts)):
        text = path.read_text()
        for match in CONTRACT_DOMAIN_WORDS.finditer(text):
            number = text.count("\n", 0, match.start()) + 1
            errors.append(f"{path.relative_to(root)}:{number}: domain vocabulary in kernel contract: {match.group(0)}")
        for number, line in enumerate(text.splitlines(), 1):
            match = IMPORT.match(line) if path.suffix == ".swift" else None
            if match and (match.group(1) in DOMAIN_MODULES | UI_MODULES | {"AppFoundation"} or match.group(1).startswith("MSRU")):
                errors.append(f"{path.relative_to(root)}:{number}: kernel contract must not import {match.group(1)}")

    for path in sorted((root / "MSRU").rglob("*.swift")):
        if path.is_relative_to(root / "MSRU/Platform"):
            continue
        source = path.read_text()
        for number, line in enumerate(source.splitlines(), 1):
            match = IMPORT.match(line)
            if match and match.group(1) in {"AppKit", "UIKit"}:
                errors.append(
                    f"{path.relative_to(root)}:{number}: "
                    "Product native UI imports belong in MSRU/Platform"
                )
        for match in WINDOW_CREATION.finditer(source):
            number = source.count("\n", 0, match.start()) + 1
            errors.append(
                f"{path.relative_to(root)}:{number}: "
                "Native windows/split controllers belong in MSRU/Platform"
            )
    return errors


if __name__ == "__main__":
    if not (SOURCES / "AppFoundation").is_dir() or not (ROOT / "MSRU").is_dir():
        sys.exit("Expected MSRU and AppFoundation source directories")
    failures = violations(ROOT)
    if failures:
        sys.exit("\n".join(failures))
    print("Architecture source checks passed (imports and native window construction).")

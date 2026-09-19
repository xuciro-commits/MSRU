#!/usr/bin/env python3
"""Source guard for direct View/Representable conformances and their #Preview sites.

This is deliberately not a Swift type checker. Builds verify platform availability
and macro expansion; tests verify fixture isolation. Indirect protocol conformances
need code review. Comments and strings cannot satisfy the preview requirement.
"""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
DECLARATION = re.compile(
    r"\b(?:struct|class|enum|extension)\s+(\w+(?:\.\w+)*)\s*"
    r"(?:<[^{}]*?>\s*)?:\s*([^{}]+)"
)
VIEW_PROTOCOL = re.compile(
    r"(?:^|[,\s&])(?:SwiftUI\.)?(?:View|NSViewRepresentable|"
    r"NSViewControllerRepresentable|UIViewRepresentable|UIViewControllerRepresentable)"
    r"(?=$|[,\s&])"
)


def view_declarations(source: str):
    """Direct conformances, including later inheritance entries and extensions."""
    seen = set()
    for declaration in DECLARATION.finditer(source):
        inheritance = re.split(r"\bwhere\b", declaration.group(2), maxsplit=1)[0]
        name = declaration.group(1)
        if VIEW_PROTOCOL.search(inheritance) and name not in seen:
            seen.add(name)
            yield name, declaration.start()



def code_only(source: str) -> str:
    # Preserve offsets for diagnostics; handle nested Swift block comments.
    result = list(source)
    index = 0
    while index < len(source):
        start = index
        if source.startswith('//', index):
            end = source.find('\n', index)
            index = len(source) if end < 0 else end
        elif source.startswith('/*', index):
            depth = 1
            index += 2
            while index < len(source) and depth:
                if source.startswith('/*', index):
                    depth += 1
                    index += 2
                elif source.startswith('*/', index):
                    depth -= 1
                    index += 2
                else:
                    index += 1
        elif source[index] == '"':
            delimiter = '"""' if source.startswith('"""', index) else '"'
            index += len(delimiter)
            while index < len(source):
                if source[index] == '\\':
                    index += 2
                elif source.startswith(delimiter, index):
                    index += len(delimiter)
                    break
                else:
                    index += 1
        else:
            index += 1
            continue
        for position in range(start, min(index, len(result))):
            if result[position] != '\n':
                result[position] = ' '
    return ''.join(result)


def preview_bodies(source: str) -> list[str]:
    result = []
    for macro in re.finditer(r'#Preview\b', source):
        start = source.find('{', macro.end())
        if start < 0:
            continue
        depth = 1
        end = start + 1
        while end < len(source) and depth:
            depth += (source[end] == '{') - (source[end] == '}')
            end += 1
        result.append(source[start:end])
    return result


def main() -> None:
    failures = []
    count = 0
    for directory in (ROOT / 'MSRU', ROOT / 'Packages/AppFoundation/Sources/AppFoundationUI'):
        for path in sorted(directory.rglob('*.swift')):
            source = code_only(path.read_text())
            bodies = '\n'.join(preview_bodies(source))
            for name, offset in view_declarations(source):
                count += 1
                if not re.search(r'\b' + re.escape(name) + r'\s*(?:<[^{}]*?>\s*)?\(', bodies):
                    line = source.count('\n', 0, offset) + 1
                    failures.append(f'{path.relative_to(ROOT)}:{line}: {name} needs a same-file #Preview')
            if path.is_relative_to(ROOT / 'MSRU'):
                for constructor in ('ApplicationModel', 'ProviderManagerStore', 'LocalLibraryStore',
                                    'AppleMusicLibraryStore', 'PlaybackController', 'LibraryStore'):
                    if re.search(r'\b' + constructor + r'\s*\(\s*\)', bodies):
                        failures.append(f'{path.relative_to(ROOT)}: live {constructor}() in preview')
    if failures:
        sys.exit('\n'.join(failures))
    print(f'Preview source checks passed for {count} View/Representable declarations.')


if __name__ == '__main__':
    main()

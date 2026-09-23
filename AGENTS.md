# AGENTS.md

Start here (Claude Code reaches this file through `CLAUDE.md`). This file is enough to work safely; read other docs only when the task touches them.

## What this repository is

- **MSRU** — a real, shipping Apple-native music product (macOS first, iPadOS/iOS) whose original objective is professional music-library management, plus listening.
- **AppFoundation** — a domain-neutral Apple client layer (Swift/SwiftUI toolkit) used by MSRU.
- **The current home of the business-platform design** (`Docs/Platform.md`, `Docs/ADR/`). The platform itself — contracts, Go backend, Rust components — will live in a separate repository (ADR-0003). Hotel and manufacturing code never go here.

## What it is not

- Not the platform kernel: AppFoundation is one client capability. Do not grow it into "the platform".
- Not a music framework: nothing music-specific belongs in AppFoundation, and nothing in the platform design may assume music, hotel or any domain's current shape.
- Not a place for planning notes: see "Documentation" below.

## Repository map

| Path | Contents |
|---|---|
| `MSRU/App` | Composition root (`ApplicationModel`, `Composition/MSRUApplication.swift`), commands, scenes, navigation, lifecycle, intents |
| `MSRU/Features` | Product UI features |
| `MSRU/Platform` | AppKit/UIKit/SwiftUI platform adapters, windows, menu bar, restoration. The only app folder allowed to import AppKit/UIKit or create windows/split controllers |
| `MSRU/Shared/UI/Music` | Shared music views (cards, components) |
| `MSRU/PreviewSupport` | Deterministic preview fixtures (`MSRUPreviewData`) |
| `Packages/AppFoundation` | Apple client layer: `AppFoundation` (no UI) + `AppFoundationUI` (native code only under `AppFoundationUI/Platform`) |
| `Packages/MusicDomain` | Music domain package, layered `MusicPlayback` → `MusicLibrary` → `MusicDomain`: types/toolkits, library + persistence (GRDB/SQLite + migrations), identity, import, providers, radio, queries, playback ([ADR-0004](Docs/ADR/0004-music-domain-packages.md)) |
| `Packages/MediaLibrary`, `Packages/SubsonicKit` | Music source abstraction, Subsonic client |
| `Packages/ChromaSwift`, `Packages/MSRUCodecFFmpeg` | Chromaprint wrapper (vendored `chromaprint/` source), FFmpeg micro XCFramework (vendored, built by script) |
| `MSRUTests`, `MSRUUITests` | App unit/contract tests (Swift Testing), process-level UI tests |
| `Scripts/` | `verify.sh`, `verify-architecture.py`, `verify-previews.py`, `repo-health.py` |
| `Docs/` | Canonical documentation (below) |

## Canonical documents

| Doc | Read when |
|---|---|
| `Docs/Intent.md` | Always relevant: goals, quality bar, collaboration rules |
| `Docs/WorkQueue.md` | Choosing or finishing work; the only active plan |
| `Docs/Platform.md` | Any platform/kernel/boundary question |
| `Docs/AppleClient.md` | Working in AppFoundation or MSRU scenes, features, UI, concurrency |
| `Docs/Music.md` | Working on the music domain: identity, metadata, storage, playback facts |
| `Docs/ADR/` | Before changing a decision recorded there |

Conflicts: the owner's latest instruction decides requirements; code and fresh verification decide facts; fix contradictions in the owning doc instead of writing a new one.

## Boundaries that must not change silently

1. AppFoundation has **no package dependencies, no `@_exported` imports, no domain vocabulary** in public API, and `AppFoundation` (core) imports no UI framework. Enforced by `Scripts/verify-architecture.py`.
2. Dependencies point from app → domain packages → AppFoundation; never the reverse.
3. Native AppKit/UIKit code stays in `MSRU/Platform` and `AppFoundationUI/Platform`.
4. State has one owner: scene state in the scene, shared services in the application; no convenience globals. Async work defines cancellation and stale-result behaviour.
5. Platform kernel concepts (Platform.md §4) are hypotheses with promotion rules; a slice may not change the kernel — record friction in the work queue instead.
6. The kernel is a language-neutral contract (ADR-0002); do not make any single language's package "the kernel".
7. Do not claim unverified capabilities (e.g. bit-perfect audio, performance numbers not measured on the current tree).

## Where code belongs

- Music-specific types, rules, storage and integrations → the `Packages/MusicDomain` targets, never AppFoundation or the app target.
- Reusable, domain-neutral Apple client mechanisms → AppFoundation, only when at least two real uses share the same lifetime and failure semantics.
- Platform/kernel/server code → the platform repository (until it exists: design only, in `Docs/Platform.md`).
- Product UI → `MSRU/Features`; platform adapters → `MSRU/Platform`.

## Build, test, lint

Requirements: macOS 27 with Xcode 27 (deployment target 27.0, Swift 6 language mode, `MemberImportVisibility` on — import every module whose members you use).

```sh
Scripts/verify.sh gates      # architecture + preview guardrails (seconds)
Scripts/verify.sh packages   # gates + swift test for AppFoundation, MusicDomain, MediaLibrary, SubsonicKit
Scripts/verify.sh app        # gates + macOS unit tests (scheme MSRU-UnitTests) + iOS Simulator build (scheme MSRU)
Scripts/verify.sh            # everything; logs in .build/verify/
```

After any change, the gates, the affected package tests, the macOS unit-test build and the iOS Simulator build must pass. UI tests (`-only-testing:MSRUUITests`, scheme `MSRU`, signed runner) and `MacAudioHardwareSmokeTests` touch the real machine; run them only when the task concerns them. There is no formatter or linter configured: follow surrounding style, keep `git diff --check` clean. Every View/Representable needs a same-file `#Preview` using fixtures; previews and tests never use live network, accounts or user data. Temporary probes are deleted after use; only lasting regressions become tests.

## Migrations and compatibility

- Database changes go through `Packages/MusicDomain/Sources/MusicLibrary/Persistence/Core/AppDatabaseMigrations.swift` as new, forward-only, re-runnable migrations; never edit a shipped migration. A failed migration must not overwrite user data; keep a recovery path.
- Persisted/transferred payloads (restoration records, settings, caches) are versioned and decoded per record; corrupt or unknown data is preserved, not replaced by empty state.
- Breaking changes follow expand → migrate → contract. Do not keep two production paths for one responsibility after a migration completes, and do not add forwarding shims as an end state.
- User files are never hard-deleted (use the Trash); original tags are never destroyed.

## When an ADR is required

Write or update an ADR in `Docs/ADR/NNNN-title.md` (Status, Context, Decision, Consequences, Revisit when; under a page) for: kernel contract changes; layer or module boundary changes; repository splits; new runtimes or languages; persistence/migration strategy; authority or sync models; anything costly to reverse. Not for routine refactors.

## Documentation

Repository docs are durable knowledge, not reasoning. Do not add new doc files for plans, reviews, investigations or summaries; update the owning canonical doc or the work queue, and delete temporary material once folded in. Done work is removed from the work queue (git keeps history). Report results in chat, not in new files.

## Never treat as source

`.build/`, `**/.build/`, `**/.swiftpm/`, DerivedData, `xcuserdata/`, `*.xcuserstate`, `.DS_Store`, `Packages/MSRUCodecFFmpeg/.build-ffmpeg*/`, `.vendor-stage.*`. Vendored artifacts — `Packages/MSRUCodecFFmpeg/Vendor/` (rebuild only with `Packages/MSRUCodecFFmpeg/Scripts/build-ffmpeg-micro-apple.sh`) and `Packages/ChromaSwift/chromaprint/` — are not edited by hand. Do not search or refactor inside these directories.

# Work Queue

The only list of active work. Each item: goal, boundary, done-when, status. When an item is done, delete it (git history keeps it) and fold any lasting knowledge into the canonical docs. Verification notes prove only the tree they were run on.

## Platform track

| # · Status | Task | Done when |
|---|---|---|
| **75 · verified 2026-09-24, awaiting owner spot-check** | Remove music leakage from AppFoundation: drop GRDB/ChromaSwift/MediaLibrary/SubsonicKit deps and `@_exported`; move music types to `Packages/MusicDomain`, music cards to `MSRU/Shared/UI/Music/MusicCards.swift`; delete dead types (`IdentityEvidence`, `EntityCluster`, fingerprint typealiases); add explicit imports; guard with `verify-architecture.py`. Package name `AppFoundation` kept ([AppleClient.md](AppleClient.md)) | `Scripts/verify.sh` passes on macOS (gates, package tests, macOS unit tests, iOS Simulator build); owner spot-checks the app |
| **76 · in progress** | Music domain packages. Done: `MSRU/Music` moved into `MusicLibrary`/`MusicPlayback` targets ([ADR-0004](ADR/0004-music-domain-packages.md)); transitional link-only deps removed from `MusicDomain`. Remaining: unify the two source representations (`MediaLibrary.LibrarySource` vs SQLite `sources`, F-4) and fold MediaLibrary/SubsonicKit into the domain; narrow the mechanically widened `public` surface. User-visible behaviour unchanged | App assembles from packages; `verify.sh` passes; owner spot-checks main flows |
| **77 · ready** | Kernel contract v0 for K1–K5 and K7 ([Platform.md §4](Platform.md)): schemas, semantics, conformance vectors, executable from Go and Swift. Choose the format (JSON Schema, Protobuf, …) and record it in ADR-0002. Only what the Hotel and Music slices need | Vectors run in Go and Swift; no domain vocabulary |
| **78 · ready (parallel, no code)** | Manufacturing discovery with real scenarios: work-order lifecycle, quality nonconformance, equipment state/downtime. Map each step to K1–K9 and list predicted friction | Findings folded into Platform.md (validation section) and the friction list below; raw notes not kept |
| **79 · after 77** | Hotel vertical slice in the platform repository: Go server (tenancy, principals, policy hook, change records; reservations and capacity conflicts in the domain), one client (Tauri suggested), one simulated channel connector; draft → confirm → modify/cancel; two staff roles. **May not change the kernel**; records friction | Rejection, conflict and offline-pending flows reproducible; friction recorded |
| **80 · after 76, 77** | Music retrofit slice: import → identity → claims → user decisions expressed through contract v0; user corrections gain principal and history; decide on content-derived IDs (see [Music.md](Music.md#known-gaps-against-the-platform-kernel)). No user-visible regression; reversible migration | Vectors pass; migration reversible; tests pass |
| **81 · after 79, 80** | Compare and revise: update kernel statuses, resolve friction, decide shared Rust edge core (ADR) | Platform.md updated; refactor tasks for both apps listed here |
| **82 · after 81** | Evolution drills E1 (Hotel → coworking/serviced apartments) and E2 (Music → shared library) | For each drill, which layer changed; kernel changes carry ADRs |
| **83 · after 81** | First manufacturing slice from #78, including edge observations | Same rules as #79 |

Repository split ([ADR-0003](ADR/0003-repository-split.md)) happens once #75–#77 are done.

## Open friction (temporary; delete entries once resolved)

| ID | Domain | Kind | Observation | Resolution path |
|---|---|---|---|---|
| F-2 | Music | missing (K2–K4) | User overrides have no principal or history and are separate from claims | #80 |
| F-3 | Music | missing (K1) | Routes never address a specific entity; references never crossed a window, runtime or process | Hotel slice #79 pressures cross-runtime references |
| F-4 | Music | mapping (K8) | Source capabilities are a music-specific bitmask; `MediaLibrary.LibrarySource` and the SQLite `sources` table coexist | #76 unifies; K8 written language-neutrally in #77 |

## Music product track

Music keeps shipping. Re-emphasize professional library management (identity, claims, review, corrections, sources, de-duplication) — it is also the prerequisite for drills E2/E3. Listening features (e.g. LAN remote control) are scheduled on owner request. Unproven audio claims (bit-perfect, DAC exclusivity/rate switching/hot-plug) need dedicated hardware verification before being stated.

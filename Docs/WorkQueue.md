# Work Queue

The only list of active work. Each item: goal, boundary, done-when, status. When an item is done, delete it (git history keeps it) and fold any lasting knowledge into the canonical docs. Verification notes prove only the tree they were run on.

Platform work (#79 Hotel slice onward, open friction F-3 to F-9) is tracked in the platform repository's `docs/WorkQueue.md`. Follow-ups from #76: narrow the mechanically widened `public` surface of the music targets; delete the legacy UserDefaults server list once no pre-v6 installs remain.

## Music product track

Music keeps shipping. Re-emphasize professional library management (identity, claims, review, corrections, sources, de-duplication) — it is also the prerequisite for drills E2/E3. Next: keep recording IDs stable across rescans (reuse the recording bound to an asset; see Music.md known gaps). Shared library (platform drill E2, ADR-0006 there): give each library a globally unique tenant ID instead of `local` (a migration), queue decisions in a K5 outbox when the authority is a server, upload the log for adoption. Platform friction aimed here: routes that open one entity (F-3) and Subsonic/watched folders as K8 poll connectors (F-4). Listening features (e.g. LAN remote control) are scheduled on owner request. Unproven audio claims (bit-perfect, DAC exclusivity/rate switching/hot-plug) need dedicated hardware verification before being stated.

## Product honesty and one-truth pass (owner request, 2026-09)

Goal: every surface shows real data or real capability, each responsibility has one owner and one entry point, and the product reads as manage-your-library first. Boundary: app target and MusicDomain only; no kernel change. Done so far: fake Home picks/mixes, fake Settings cards and Advanced tab, the synthetic visualizer and the separate Add Music page are gone. Sources is the one place to add, check and remove files, watched folders, servers and Apple Music; sidebar is Discover / Library / Source & Import (Sources, Metadata Center). Remaining, in order:

1. **Library cleanup as a first-class flow.** Metadata Center (review, fingerprints), de-duplication (a sheet inside Songs) and per-track corrections live in three places. Give cleanup one workspace: queue of issues (unmatched, duplicates, missing artwork, bad tags), each with preview, apply and undo through the user decision log. Done when every cleanup action is reachable from that workspace and reversible.
2. **Localization debt.** ~120 hardcoded Chinese UI literals (Browse, Library, Albums, Artists, Playlists, Import Review) bypass the English-source catalog, so ja/zh-Hant/bo users see Simplified Chinese; `ContinuousShelfView` titles are plain `String` and never localize. Also drop vendor branding ("极空间") from generic copy. Done when production views contain no CJK literals outside matching/parsing data.
3. **Convenience globals.** 19 app-owned `static shared` singletons (`AppDatabase`, `LibraryQueryEngine`, `SourceRuntimeCoordinator`, `LocalFingerprintRegistry`, `LocalArtworkStorage`, …) contradict boundary 4. Move each to `ApplicationModel` ownership and inject; start with those views reach directly (`SourceRuntimeCoordinator`, `LibraryQueryEngine`, `LocalFingerprintRegistry`). Done when views reach no `.shared` except Apple frameworks.
4. **Dead Home inputs.** `ListenNowView.onSelect` and `ListenNowBehaviorSnapshot.heroItem` have no reader since the fake cards went; remove them.

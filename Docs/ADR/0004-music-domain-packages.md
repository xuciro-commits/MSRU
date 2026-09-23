# ADR-0004: Music code lives in layered targets of one domain package

**Status:** Accepted (2026-09-24)

**Context.** After #75, roughly 27k lines of music code (library, persistence, identity, import, providers, radio, queries, playback) still compiled inside the app target, so the app was both product shell and domain. The code had only three couplings to the app: an artwork view, an image-pipeline reference type and one stale comment. Playback depended on library types; the library depended on playback in only two places (lyrics sync and queue purging after deletion).

**Decision.** `Packages/MusicDomain` holds targets that depend strictly downward: `MusicPlayback` → `MusicLibrary` → `MusicDomain`, with `SubsonicKit` as a leaf used by the library and playback. `MusicDomain` stays Foundation-only; `MusicLibrary` owns GRDB persistence and migrations; `MusicPlayback` owns engine, output, DSP and codecs. No target imports UI frameworks. The library notifies playback of removed tracks through the `LocalTrackRemovalObserver` protocol instead of importing it. Moved targets use the app's concurrency settings (default `MainActor` isolation, approachable concurrency), so behaviour does not change. Implicit initializers became explicit `nonisolated public` ones. `Scripts/verify-architecture.py` enforces the layering. Views and app image-pipeline mappings stay in `MSRU/Shared/UI/Music`.

**Consequences.** The app target composes, hosts features and adapts platforms. The public surface is broad because the move added `public` mechanically; narrowing it is follow-up work, not a precondition. One package with several targets keeps a single manifest and shared settings. The former MediaLibrary package (an unused cross-source browse layer plus a provider registry) was deleted; its three live types moved into a `SubsonicKit` leaf target, and the SQLite `sources` table became the single source registry.

**Revisit when** a target needs a different release cadence or a second product consumes one of them, or when the public surface is narrowed enough to split packages cleanly.

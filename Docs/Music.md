# Music Domain (MSRU)

MSRU is a real, shipping product and the platform's long-term validation domain for personal, local-first, edge-side capabilities. Its original objective is a **professional music-library management system**; listening features are valuable but must not crowd out that objective. Platform context: the platform repository's `docs/Platform.md`. Client-layer rules: [AppleClient.md](AppleClient.md).

## Where the code lives

| Path | Content |
|---|---|
| `Packages/MusicDomain` — target `MusicDomain` | UI-free, Foundation-only types and toolkits: fingerprints and signatures, external catalogue contract, metadata overlay and LRC parsing, entity aliases, version groups, matching/scoring, safe file organizer, presentation models |
| `Packages/MusicDomain` — target `MusicLibrary` | Library, persistence (GRDB/SQLite + migrations), identity, import pipeline, catalogue providers, provider management, queries, radio, lyrics fetching |
| `Packages/MusicDomain` — target `MusicPlayback` | Playback controller and queue, PCM engine, CoreAudio output, DSP, codecs, synchronized lyrics state |
| `MSRU/Features`, `MSRU/Shared/UI/Music` | Product UI; the app target composes, hosts features and adapts platforms ([ADR-0004](ADR/0004-music-domain-packages.md)) |
| `Packages/MusicDomain` — target `SubsonicKit` | Subsonic/OpenSubsonic client, Keychain credentials, capability probe; depends on nothing in the product |
| `Packages/ChromaSwift`, `Packages/MSRUCodecFFmpeg` | Chromaprint wrapper; FFmpeg micro build (`Scripts/build-ffmpeg-micro-apple.sh`, vendored XCFramework) |

## Sources

- The SQLite `sources` table is the only persisted registry of sources (local folders and Subsonic servers; `username` since migration v6). `SourceRuntimeCoordinator` owns them at runtime: it keeps one authenticated client per server, probes capabilities and holds each server's connection status (not persisted). Feature code reaches servers through `SubsonicServerStore`, which adds no state.
- A Subsonic server has a source ID `src_subsonic_<8 hex>` and a server key `subsonic_<8 hex>` (`SourceID.serverKey`). The key names the Keychain account and appears inside persisted artwork and remote-item references, so it must not change; convert only through `SourceID.serverKey` / `SourceID(serverKeyOrSourceID:)`.
- The Library is one index. Web catalogue tracks (Openverse) are members under the `src_openverse` source (`WebLibraryStore`); migration v7 moved them out of the former `saved_library_*` tables, which are no longer read and stay as a recovery path. Library membership is not a preference: nothing maps membership to `library_entries.is_favorite`.
- The pre-v6 UserDefaults list `com.msru.subsonic.servers` is imported once and kept untouched as a recovery path; delete it in a later contract step.

## Model

A file is not a song; a name is an attribute, not an identity.

```text
Artist (aliases) ─ ArtistCredit
Work ─ Recording ─┐
ReleaseGroup ─ Release ─ Track (medium position)
                  └─ Asset (format, duration, signature, fingerprint) ─ FileAsset (source + relative path) / StreamAsset
```

- **Identity ≠ metadata ≠ classification ≠ organization.** Canonical IDs are typed and stable; file paths, MBIDs and Swift `hashValue` are never canonical identity. Merges/re-clusterings are recorded in `entity_redirects`; external IDs live in `external_identifiers`.
- **Source ≠ asset ≠ file ≠ recording.** One recording may have several assets across sources (local FLAC, NAS MP3, stream); the user library holds one entry per recording and playback picks the best available asset. Unavailable sources stay browseable offline and fail playback fast with `.sourceUnavailable`.
- **Moves are not new files.** File signature / fingerprint matching turns a delete+add into a path update in one transaction; play counts, favourites and playlists survive. Local paths are canonicalized (`resolvingSymlinksInPath().standardizedFileURL`) before becoming identity input.
- **Metadata is claims with provenance.** Raw observations go to `metadata_claims` (source, confidence, time); the resolved value per field goes to `metadata_resolutions` with the winning claim. Priority: user override > canonical (MusicBrainz/AcoustID) > file tags. Original file tags are never destroyed; tag write-back is explicit.
- **Duplicates are graded**, not boolean: identical file; same recording, different encoding; different quality; different master/release; different performance. Only the first is a true duplicate; the rest are versions with a chosen primary.
- **Matching is weighted scoring with confidence tiers** (`ConfidenceTier`): ≥ 0.90 auto-link, 0.60–0.90 goes to Import Review for the user, < 0.60 stays with original tags. Albums are identified by clustering files (folder, track count, positions, durations) and looking up whole releases; single fingerprints identify recordings only. LLMs may propose parsing hints (file names, aliases) but never decide identity.
- **Deletion cascades inside one SQLite transaction** (assets, favourites, playlist references); multi-source favourites keep their other sources; physical files go to the system Trash, never hard-deleted. Fingerprints of deleted tracks are kept as memory until the user purges them.

## Storage and performance facts

SQLite via GRDB (WAL) is the single source of truth; the legacy JSON library was migrated once and is not dual-written. Local tracks load in pages of 128, album/artist summaries in pages of 64, with search, sorting and exact positioning in SQLite (FTS5 including Chinese, pinyin and aliases). Spotlight indexing, playback queues and maintenance tasks read page by page.

Measured 2026-09-24 (Mac15,7, Debug, 50,000 tracks / 1,000 albums / 100 artists): isolated storage path 47–53 ms with ~9.5 MB incremental RSS (previously 601–606 ms / 66–69 MB); app process to data-ready ≈ 0.7 s, whole-process RSS −26 %, library-attributable RSS −76 %. The earlier targets of < 100 ms whole-app startup and −70 % total RSS were **not** met; the user accepted the measured result. Reproducible storage probe: `MSRUTests/Benchmarks/Stage2StorageBenchmarkTests.swift` (skipped by default).

## Playback facts

Apple-decodable local files play through a PCM engine (`AVAudioPlayerNode` → 10-band `AVAudioUnitEQ` → main mixer) with gapless scheduling for same-format neighbours; other files use AVPlayer. NAS (Subsonic) album queues download to session-owned temporary files for continuity. On macOS the output device is selectable via CoreAudio HAL with optional sample-rate matching and hog mode. EBU R128 loudness is computed on explicit request and cached (file size + mtime signature). **Bit-perfect output, physical DAC rate switching, exclusivity and hot-plug are not proven** and must not be claimed; the PCM path is Float32 through the mixer.

## User decisions

User corrections of a track's title, artist or album are decisions in `user_decisions`, a K4 change log (contract `v1alpha1`) with principal, device authority, causation and idempotency. The personal library is one tenant (`local`) with one principal (`local-owner`). `user_metadata_overrides` is only the current-value projection; restoring a field is a new decision, never a deletion of history. Corrections never change file tags, scanned values or IDs, and never reach ID derivation: they are applied only when tracks are read for display (`fetchPage`), never in paths that save tracks. A decision may cite the metadata claims it overrides (`evidence_fact_ids`, C11). `MusicLibraryTests` runs the contract's K4 vectors (pinned copy in `Tests/MusicLibraryTests/Vectors`) against this log.

**IDs.** Content-derived IDs are de-duplication keys at first import; once assigned an ID is opaque (K1) and corrections never re-derive it.

## Known gaps against the platform kernel

- A rescan derives the recording ID again from the file's title + artist, so retagging a file creates a new recording (favourites and corrections stay on the old one). Fix: reuse the recording already bound to the asset.
- User corrections are not yet claims: resolution between tags, provider claims and corrections is a fixed priority, not a K2 claim set. Corrections apply to the Library track list and the inspector; album and artist views still show scanned values.
- Routes are 11 static sections; no route addresses a specific entity yet.
- Authority is declared only for user decisions (device); Subsonic data is externally authoritative by convention, not by a K5 declaration.

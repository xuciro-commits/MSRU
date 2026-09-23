# Music Domain (MSRU)

MSRU is a real, shipping product and the platform's long-term validation domain for personal, local-first, edge-side capabilities. Its original objective is a **professional music-library management system**; listening features are valuable but must not crowd out that objective. Platform context: [Platform.md](Platform.md). Client-layer rules: [AppleClient.md](AppleClient.md).

## Where the code lives

| Path | Content |
|---|---|
| `Packages/MusicDomain` — target `MusicDomain` | UI-free, Foundation-only types and toolkits: fingerprints and signatures, external catalogue contract, metadata overlay and LRC parsing, entity aliases, version groups, matching/scoring, safe file organizer, presentation models |
| `Packages/MusicDomain` — target `MusicLibrary` | Library, persistence (GRDB/SQLite + migrations), identity, import pipeline, catalogue providers, provider management, queries, radio, lyrics fetching |
| `Packages/MusicDomain` — target `MusicPlayback` | Playback controller and queue, PCM engine, CoreAudio output, DSP, codecs, synchronized lyrics state |
| `MSRU/Features`, `MSRU/Shared/UI/Music` | Product UI; the app target composes, hosts features and adapts platforms ([ADR-0004](ADR/0004-music-domain-packages.md)) |
| `Packages/MediaLibrary`, `Packages/SubsonicKit` | Source abstraction and Subsonic/OpenSubsonic client (to be folded into the Music domain; two source representations currently coexist) |
| `Packages/ChromaSwift`, `Packages/MSRUCodecFFmpeg` | Chromaprint wrapper; FFmpeg micro build (`Scripts/build-ffmpeg-micro-apple.sh`, vendored XCFramework) |

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

## Known gaps against the platform kernel

- User overrides (`user_metadata_overrides`) are separate from claims and record no principal and no history (K2–K4). A shared library (drill E2) breaks this first.
- Canonical IDs are deterministic hashes of normalized metadata (e.g. title + artist), so corrections and merges depend on redirects; kernel K1 expects opaque IDs once assigned. Decide in the Music retrofit slice whether content-derived IDs remain acceptable as *de-duplication keys* only.
- Routes are 11 static sections; no route addresses a specific entity yet.
- Authority is implicit (local library device-authoritative, Subsonic externally authoritative) rather than declared (K5).

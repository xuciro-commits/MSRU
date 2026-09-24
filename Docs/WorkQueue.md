# Work Queue

The only list of active work. Each item: goal, boundary, done-when, status. When an item is done, delete it (git history keeps it) and fold any lasting knowledge into the canonical docs. Verification notes prove only the tree they were run on.

## Platform track

| # · Status | Task | Done when |
|---|---|---|
| **78 · ready (parallel, no code)** | Manufacturing discovery with real scenarios: work-order lifecycle, quality nonconformance, equipment state/downtime. Map each step to K1–K9 and list predicted friction | Findings folded into Platform.md (validation section) and the friction list below; raw notes not kept |
| **79 · ready** | Hotel vertical slice in the platform repository: Go server (tenancy, principals, policy hook, change records; reservations and capacity conflicts in the domain), one client (Tauri suggested), one simulated channel connector; draft → confirm → modify/cancel; two staff roles. **May not change the kernel**; records friction | Rejection, conflict and offline-pending flows reproducible; friction recorded |
| **81 · after 79** | Compare and revise: update kernel statuses, resolve friction, decide shared Rust edge core (ADR) | Platform.md updated; refactor tasks for both apps listed here |
| **82 · after 81** | Evolution drills E1 (Hotel → coworking/serviced apartments) and E2 (Music → shared library) | For each drill, which layer changed; kernel changes carry ADRs |
| **83 · after 81** | First manufacturing slice from #78, including edge observations | Same rules as #79 |

Repository split ([ADR-0003](ADR/0003-repository-split.md)) is due now that the kernel contract exists (`Contract/`, K1–K5 and K7): `Contract/` moves first, before #79 adds server code. Follow-ups from #76: narrow the mechanically widened `public` surface of the music targets; delete the legacy UserDefaults server list once no pre-v6 installs remain.

## Open friction (temporary; delete entries once resolved)

| ID | Domain | Kind | Observation | Resolution path |
|---|---|---|---|---|
| F-3 | Music | missing (K1) | Routes never address a specific entity; references never crossed a window, runtime or process | Hotel slice #79 pressures cross-runtime references |
| F-4 | Music | mapping (K8) | Source capabilities are a music-specific bitmask (`SourceCapabilities`), and Subsonic keeps its own `LibraryCapabilities` projected onto it | K8 specified in the contract when #79 builds the first connector |

## Music product track

Music keeps shipping. Re-emphasize professional library management (identity, claims, review, corrections, sources, de-duplication) — it is also the prerequisite for drills E2/E3. Next: keep recording IDs stable across rescans (reuse the recording bound to an asset; see Music.md known gaps). Listening features (e.g. LAN remote control) are scheduled on owner request. Unproven audio claims (bit-perfect, DAC exclusivity/rate switching/hot-plug) need dedicated hardware verification before being stated.

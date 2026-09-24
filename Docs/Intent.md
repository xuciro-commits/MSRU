# Intent and Product Direction

Durable statement of what the owner wants. The owner's latest explicit instruction always wins; update this file when direction changes rather than adding new ones.

## What we are building

1. **A business platform** with server and edge/client runtimes, multi-tenant, able to support personal local-first apps and organizational apps where a server is authoritative — eventually real operational businesses such as manufacturing plants. See the platform repository's `docs/Platform.md`.
2. **Music (MSRU)** as a real product for listeners and serious library managers, and as the long-term validation domain for local-first, personal, edge-side capabilities.

The deepest goal is a platform that **supports change itself**. It must not encode an organization's or application's current shape as its permanent identity. Music may become a professional library manager, a shared library or a multi-media product; Hotel may become coworking or long-stay capacity management; a manufacturer may change products, processes, equipment, structure or operating model. Domains may be rewritten; the deeper contracts must stay coherent.

## How we validate

- Applications are validation environments, not the source of truth for platform architecture. Music, Hotel (reference, synthetic) and manufacturing (real) apply different pressures; the platform is not proven because Music and Hotel both fit it.
- Tensions between domains are evidence for refining the platform, not triggers for special cases.
- Kernel stability is judged by evolution: domain evolution should mainly change the domain; the kernel changes only for a genuinely missing cross-domain capability. No fixed numeric threshold.

## Technology direction

Go for the primary backend; Rust where it gives a real systems/performance advantage; Tauri/Rust for the cross-platform desktop client; Swift where Apple-native capabilities and deep local integration matter. The server must not couple to Apple because the first app was Swift. The kernel is language-neutral contracts plus conformance tests, without four parallel implementations.

On Apple clients: modern Swift 6, SwiftUI first, AppKit/UIKit inside platform adapters; native controls, materials and platform conventions (see [AppleClient.md](AppleClient.md)). macOS, iPadOS/iOS continue; watchOS where it serves a real device task; visionOS paused.

## Product quality bar

- Main flows have complete start, progress, completion, failure and recovery behaviour.
- Every view has a deterministic `#Preview`; previews and tests never touch live accounts, network or personal data.
- Refactors change directories, responsibilities and dependencies, not just names. Migrations are closed: no two long-lived paths for one responsibility. Delete old code once it is confirmed unused, and protect existing valid work.
- Report what was actually verified and what was not; historical passes are not evidence for the current tree. The AI verifies builds, contracts and interfaces; the owner accepts visual quality, feel and end-to-end behaviour.

## Documentation principles

- Repository docs are **durable project knowledge**, not the reasoning that produced it. Keep a small set: AGENTS.md, this file, the platform repository's docs, client/domain docs where a domain genuinely needs them, ADRs for decisions worth preserving, one work queue.
- Consolidate instead of appending. Hypotheses, friction notes and investigations are temporary: fold conclusions into the canonical docs or an ADR, then delete them. Git history is the archive.
- Documents describe targets; code states facts. When they disagree, record the gap.

## Working with AI

- Be concise; reason internally; do not restate requirements or narrate. Read only what the task needs.
- An explicit work request means do it, within the authorized scope; ask only when a key input is missing, the ambiguity is material, or the action crosses an authorization boundary (publishing, deleting user data, deploying, contacting others).
- If a plan is unsound, say so directly and propose a better one; do not add complexity to please, and do not silently replace the core goal.
- Written docs go into the repository at the right place; chat reports only results and locations.

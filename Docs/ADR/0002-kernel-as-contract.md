# ADR-0002: The kernel is a language-neutral contract

**Status:** Accepted (2026-09-24); the concrete schema/vector format is still open (work queue #77)

**Context.** Go (server), Rust (systems components, Tauri desktop) and Swift (Apple edge) will coexist. A kernel defined as one language's library would make that language the platform and let semantics drift in the others.

**Decision.** The kernel is its schemas, semantic rules and conformance test vectors. Go is the reference implementation. Other runtimes implement the contract and pass the same vectors, or map to it at their boundary. Cross-language boundaries are introduced only where justified; no default "implement everything in every language". Whether Swift and Tauri share a Rust edge core is deferred until a Music retrofit and a first Tauri client exist.

**Consequences.** Kernel changes are contract changes: they update schemas and vectors first, and every implementation must pass. The server is not the kernel.

**Revisit when** maintaining conformance across runtimes costs more than a shared implementation would.

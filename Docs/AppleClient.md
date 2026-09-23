# Apple Client Layer (AppFoundation)

`Packages/AppFoundation` is the **Apple client layer**: a domain-neutral Swift toolkit for building native Apple apps. It is a *capability* in the [platform](Platform.md) model, not the platform kernel. It must never contain domain vocabulary (tracks, albums, reservations…), storage engines or product packages — `Scripts/verify-architecture.py` enforces this. The package name is kept for now; renaming is cosmetic and can happen when the platform repository split happens ([ADR-0003](ADR/0003-repository-split.md)).

Targets: `AppFoundation` (no UI imports — composition, feature runtime, dependencies, routing, localization) and `AppFoundationUI` (presentation, shell resolver, native adaptation; AppKit/UIKit only under `AppFoundationUI/Platform`).

## Concepts

| Concept | Meaning |
|---|---|
| Application | One process run and its shared resources; the product's composition root (`ApplicationModel` in MSRU). Not a store for all observable state |
| Scene | One independent interaction session: navigation, selection, panel state, FeatureHosts. A window hosts a scene; it is not its identity |
| Feature | A business capability with state and actions (`Feature`/`FeatureService`/`FeatureHost`). Simple views are not forced into it |
| Runtime | Anything that owns state, tasks or external resources and can stop them. Not a suffix every layer needs |
| Route | A navigable destination in one client, typed per product. Not a platform reference (platform references are kernel K1) |
| Workspace / Context / Accessory | Main work area; inspector/preview/activity for it; persistent auxiliary UI. Where an accessory is visible says nothing about its resource lifetime |
| Shell | Presentation structure arranging workspace and auxiliary regions; `ApplicationShellResolver` is a stateless composer |
| Presentation / Renderer | UI descriptions (may contain `AnyView`, never serialized or passed across actors) and their mapping to native controls |
| Dependency | Capability delivered at construction (`DependencyValues`, live/preview/test). Preview and test never silently reach live accounts, network or user data |

Composition: features declare routes, sidebar entries and commands (`FeatureContribution`); the app installs them once through `ApplicationDefinitionBuilder`; `validate()` rejects duplicate IDs, undeclared routes and conflicting ownership. Adding a feature must not require editing renderers or unrelated features.

## Ownership and concurrency rules

- Every mutable state, task and persistent resource has an owner and a stop condition. Scene-local state (selection, navigation) belongs to the scene; application-wide services (playback, library) to the application. Nothing becomes global because it is convenient.
- Cancellation and stale-result invalidation are two duties. `FeatureHost` tasks carry a token; after cancel/replace/stop an operation can no longer send actions. Test ordering with controllable continuations, never sleeps.
- Committed work (a persisted library change) is not reverted when the scene or feature that started it closes; the feature only loses the right to update its UI.
- UI, Observation and feature state transitions run on the MainActor. CPU/IO-heavy work (decoding, fingerprinting, scanning) runs on dedicated actors with in-flight de-duplication. Cross-isolation values are `Sendable`; no blanket `@unchecked Sendable`.
- Callbacks from players/engines check that their source is still current before mutating state.
- Restoration stores only scene ID, stable route/entity IDs and minimal layout — never application state, tasks or caches. Records are versioned and decoded one by one; unknown or corrupt records are preserved (quarantined), never overwritten with empty state. Crash recovery restores the last successful write.
- Closing a scene stops its tasks; Cmd+Q keeps records of still-open scenes; closing a single window deletes its record.

## Platform geometry

The native platform layer owns real window/split/safe-area geometry (`\.workspaceSafeAreaInsets`); product composition picks policy (e.g. immersive underlap); features own presentation intent. Features never hard-code sidebar, inspector, toolbar or accessory sizes. Split geometry policy is fixed at composition time.

## UI rules

- Apple-native first: system controls, materials (Liquid Glass) and platform conventions; custom surfaces only for content the system cannot express. Do not wrap every SwiftUI control in a foundation type, and do not put every group into a rounded card.
- Platforms share business semantics, not layouts. Adapt by available space and task, not only `os(...)` checks. macOS and iPad/iOS are active; watchOS has platform code but no build target; **visionOS work is paused**.
- One operation shown in menu, toolbar, shortcut and context menu calls one use case with one enabled condition; command targets come from the focused scene, not a global "current selection".
- Selection is not opening details; switching list/grid keeps the selection. First load, empty, no results, partial failure and refresh-over-existing-content are distinct states and keep usable content.
- Accessibility: keyboard, pointer and touch; dynamic type, long text, Reduce Motion, Increase Contrast; state is never conveyed by color alone.
- Every View/Representable has a `#Preview` in the same file using deterministic fixtures (`MSRUPreviewData`), never live constructors — enforced by `Scripts/verify-previews.py`. Complex views cover content and empty states at least.
- Localization: the layer provides `LanguageSettings`/`SupportedLanguage`; apps own their String Catalog (MSRU: English, Simplified Chinese, Tibetan) and the in-app language switch.
- UI design sketches, when needed, are plain-text box diagrams inside the relevant task or doc; they describe structure and behaviour, not visuals.

## Entry points

- Composition: `MSRU/App/Composition/MSRUApplication.swift`, `AppFoundationUI/Application/ApplicationDefinition.swift`, `ApplicationShell.swift`, `Workspace/WorkspacePresentation.swift`.
- macOS scene/window lifecycle: `MSRU/Platform/macOS/` (AppDelegate, MacSceneCoordinator, restoration). Compact/iPad shell: `MSRU/Platform/SwiftUI/`.
- Contract tests: `Packages/AppFoundation/Tests`; MSRU scene/lifecycle tests: `MSRUTests/Platform`; process-level quit/relaunch: `MSRUUITests` (needs a properly signed UI runner).

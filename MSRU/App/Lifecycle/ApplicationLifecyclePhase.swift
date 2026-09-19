//
//  ApplicationLifecyclePhase.swift
//  MSRU
//


// MARK: - Application Lifecycle Phase

/*
 Platform-neutral application lifecycle state。


 initialized
      │
      ▼
 bootstrapping
      │
      ▼
    ready
      │
      ▼
 suspended
      │
      └──── resume ────► ready


 任意 non-terminated phase
      │
      ▼
 terminated


 这里没有：

 - applicationDidFinishLaunching
 - scenePhase
 - UIApplicationState
 - NSApplicationDelegate

 那些属于 platform adapters。
 */

nonisolated enum ApplicationLifecyclePhase:
    Equatable,
    Sendable {

    case initialized

    case bootstrapping

    case ready

    case suspended

    case terminated
}

//
//  LibraryProviderRegistry.swift
//  MediaLibrary
//
//  Thread-safe registry for managing active library providers.
//

import Foundation

public final class LibraryProviderRegistry: @unchecked Sendable {
    public static let shared = LibraryProviderRegistry()

    private let lock = NSLock()
    private var providers: [LibrarySourceID: any LibraryProvider] = [:]

    public init() {}

    public func register(_ provider: any LibraryProvider) {
        lock.lock()
        defer { lock.unlock() }
        providers[provider.sourceID] = provider
    }

    public func remove(_ sourceID: LibrarySourceID) {
        lock.lock()
        defer { lock.unlock() }
        providers.removeValue(forKey: sourceID)
    }

    public func provider(for sourceID: LibrarySourceID) -> (any LibraryProvider)? {
        lock.lock()
        defer { lock.unlock() }
        return providers[sourceID]
    }

    public func allProviders() -> [any LibraryProvider] {
        lock.lock()
        defer { lock.unlock() }
        return Array(providers.values)
    }

    public func allSources() -> [LibrarySource] {
        lock.lock()
        defer { lock.unlock() }
        return providers.values.map(\.source)
    }
}

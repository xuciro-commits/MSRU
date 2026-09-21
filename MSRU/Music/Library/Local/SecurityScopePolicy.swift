//
//  SecurityScopePolicy.swift
//  MSRU
//
//  Created for Runtime Sandbox Detection and Security Scoped Bookmark Policy.
//

import Foundation

/// Centralized policy for security-scoped resource management.
/// Distinguishes between sandboxed (App Store) and non-sandboxed (Developer / CLI / Test) runtimes,
/// preventing SQLite DetachedSignatures errors and balancing security resource access.
nonisolated public enum SecurityScopePolicy: Sendable {

    /// True if the current process is executing within macOS App Sandbox.
    public static var isSandboxed: Bool {
        #if os(macOS)
        return ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
        #else
        return true
        #endif
    }

    /// Default bookmark creation options conforming to the runtime sandbox state.
    public static var bookmarkCreationOptions: URL.BookmarkCreationOptions {
        #if os(macOS)
        return isSandboxed ? .withSecurityScope : []
        #else
        return []
        #endif
    }

    /// Default bookmark resolution options conforming to the runtime sandbox state.
    public static var bookmarkResolutionOptions: URL.BookmarkResolutionOptions {
        #if os(macOS)
        return isSandboxed ? .withSecurityScope : []
        #else
        return []
        #endif
    }

    /// Resolves bookmark data conforming to the policy, with graceful fallback to standard options.
    public static func resolveBookmark(_ data: Data) -> (url: URL, isStale: Bool)? {
        var isStale = false
        // 1. Primary resolution using policy options
        if let url = try? URL(resolvingBookmarkData: data, options: bookmarkResolutionOptions, relativeTo: nil, bookmarkDataIsStale: &isStale) {
            return (url, isStale)
        }

        // 2. Fallback resolution if primary was withSecurityScope and failed
        if bookmarkResolutionOptions != [] {
            if let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale) {
                return (url, isStale)
            }
        }

        return nil
    }

    /// Coordinates scoped access for a specific block of work, guaranteeing prompt release of the kernel handle.
    public static func coordinateAccess<T>(to url: URL, _ block: (URL) throws -> T) rethrows -> T {
        let hasAccess = isSandboxed ? url.startAccessingSecurityScopedResource() : false
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try block(url)
    }

    /// Coordinates async scoped access for a specific block of work, guaranteeing prompt release.
    public static func coordinateAccessAsync<T>(to url: URL, _ block: (URL) async throws -> T) async rethrows -> T {
        let hasAccess = isSandboxed ? url.startAccessingSecurityScopedResource() : false
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try await block(url)
    }

    /// Determines whether the URL resides on a local filesystem or a remote network mount (SMB/NFS/AFP).
    public static func isLocalVolume(_ url: URL) -> Bool {
        if let values = try? url.resourceValues(forKeys: [.volumeIsLocalKey]),
           let isLocal = values.volumeIsLocal {
            return isLocal
        }
        return true
    }
}

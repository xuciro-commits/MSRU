//
//  AppDependencies.swift
//  MSRU
//

import Foundation
import AppFoundation
import MusicLibrary
import MusicPlayback

// MARK: - Openverse Search

@MainActor
private enum OpenverseSearchDependencyKey: DependencyKey {
    static var liveValue: OpenverseSearchClient { .live }
    static let previewValue = OpenverseSearchClient { _ in [] }
    static let testValue = OpenverseSearchClient { _ in [] }
}

// MARK: - Playback

@MainActor
private enum PlaybackDependencyKey: DependencyKey {
    static var liveValue: PlaybackController {
        fatalError("""
        PlaybackController dependency is not configured.
        Create the application-scoped PlaybackController in ApplicationModel and inject it through DependencyValues.
        """)
    }
    static let previewValue = PlaybackController()
    static let testValue = PlaybackController()
}

// MARK: - Library

@MainActor
private enum LibraryDependencyKey: DependencyKey {
    static var liveValue: WebLibraryStore {
        fatalError("""
        WebLibraryStore dependency is not configured.
        Create the application-scoped WebLibraryStore in ApplicationModel and inject it through DependencyValues.
        """)
    }
    static let previewValue = WebLibraryStore(db: try! AppDatabase.makeEphemeral())
    static let testValue = WebLibraryStore(db: try! AppDatabase.makeEphemeral())
}

// MARK: - Radio Store Key

private enum RadioStoreDependencyKey: DependencyKey {
    @MainActor static let liveValue = RadioStore()
    @MainActor static let previewValue = RadioStore()
    @MainActor static let testValue = RadioStore()
}

// MARK: - Playlist Store Key

private enum PlaylistStoreDependencyKey: DependencyKey {
    @MainActor static let liveValue = PlaylistStore()
    @MainActor static let previewValue = PlaylistStore()
    @MainActor static let testValue = PlaylistStore()
}

// MARK: - Dependency Values

extension DependencyValues {
    @MainActor
    var openverseSearch: OpenverseSearchClient {
        get { self[OpenverseSearchDependencyKey.self] }
        set { self[OpenverseSearchDependencyKey.self] = newValue }
    }

    @MainActor
    var playback: PlaybackController {
        get { self[PlaybackDependencyKey.self] }
        set { self[PlaybackDependencyKey.self] = newValue }
    }

    @MainActor
    var webLibrary: WebLibraryStore {
        get { self[LibraryDependencyKey.self] }
        set { self[LibraryDependencyKey.self] = newValue }
    }

    @MainActor
    var radioStore: RadioStore {
        get { self[RadioStoreDependencyKey.self] }
        set { self[RadioStoreDependencyKey.self] = newValue }
    }

    @MainActor
    var playlistStore: PlaylistStore {
        get { self[PlaylistStoreDependencyKey.self] }
        set { self[PlaylistStoreDependencyKey.self] = newValue }
    }
}

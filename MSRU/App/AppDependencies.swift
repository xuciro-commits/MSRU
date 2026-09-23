//
//  AppDependencies.swift
//  MSRU
//

import Foundation
import AppFoundation
import MusicLibrary
import MusicPlayback


// MARK: - Ephemeral Library Repository

/*
 Preview / Test 专用内存 Repository。

 不访问：
 - Application Support
 - Documents
 - UserDefaults
 - 网络
 */

private actor EphemeralLibraryRepository:
    LibraryRepository {

    private var tracks:
        [LibraryTrack]


    init(
        tracks:
            [LibraryTrack] = []
    ) {

        self.tracks =
            tracks
    }


    func loadTracks()
        async throws
        -> [LibraryTrack] {

        tracks
    }


    func saveTracks(
        _ tracks:
            [LibraryTrack]
    ) async throws {

        self.tracks =
            tracks
    }
}


// MARK: - Openverse Search

@MainActor
private enum OpenverseSearchDependencyKey:
    DependencyKey {

    // MARK: Live

    static var liveValue:
        OpenverseSearchClient {

        .live
    }


    // MARK: Preview

    static let previewValue =
        OpenverseSearchClient {
            _ in

            []
        }


    // MARK: Test

    static let testValue =
        OpenverseSearchClient {
            _ in

            []
        }
}


// MARK: - Playback

@MainActor
private enum PlaybackDependencyKey:
    DependencyKey {

    // MARK: Live

    static var liveValue:
        PlaybackController {

        fatalError(
            """
            PlaybackController dependency is not configured.

            Create the application-scoped PlaybackController
            in ApplicationModel and inject it through DependencyValues.
            """
        )
    }


    // MARK: Preview

    static let previewValue =
        PlaybackController()


    // MARK: Test

    static let testValue =
        PlaybackController()
}


// MARK: - Library

@MainActor
private enum LibraryDependencyKey:
    DependencyKey {

    // MARK: Live

    static var liveValue:
        LibraryStore {

        fatalError(
            """
            LibraryStore dependency is not configured.

            Create the application-scoped LibraryStore
            in ApplicationModel and inject it through DependencyValues.
            """
        )
    }


    // MARK: Preview

    static let previewValue =
        LibraryStore(
            repository:
                EphemeralLibraryRepository()
        )


    // MARK: Test

    static let testValue =
        LibraryStore(
            repository:
                EphemeralLibraryRepository()
        )
}


// MARK: - Dependency Values

extension DependencyValues {

    // MARK: Openverse Search

    @MainActor
    var openverseSearch:
        OpenverseSearchClient {

        get {

            self[
                OpenverseSearchDependencyKey
                    .self
            ]
        }


        set {

            self[
                OpenverseSearchDependencyKey
                    .self
            ] =
                newValue
        }
    }


    // MARK: Playback

    @MainActor
    var playback:
        PlaybackController {

        get {

            self[
                PlaybackDependencyKey
                    .self
            ]
        }


        set {

            self[
                PlaybackDependencyKey
                    .self
            ] =
                newValue
        }
    }


    // MARK: Library

    @MainActor
    var library:
        LibraryStore {

        get {

            self[
                LibraryDependencyKey
                    .self
            ]
        }


        set {

            self[
                LibraryDependencyKey
                    .self
            ] =
                newValue
        }
    }


    // MARK: Radio Store

    @MainActor
    var radioStore:
        RadioStore {

        get {

            self[
                RadioStoreDependencyKey
                    .self
            ]
        }


        set {

            self[
                RadioStoreDependencyKey
                    .self
            ] =
                newValue
        }
    }


    // MARK: Playlist Store

    @MainActor
    var playlistStore:
        PlaylistStore {

        get {

            self[
                PlaylistStoreDependencyKey
                    .self
            ]
        }


        set {

            self[
                PlaylistStoreDependencyKey
                    .self
            ] =
                newValue
        }
    }
}


// MARK: - Radio Store Key

private enum RadioStoreDependencyKey:
    DependencyKey {

    @MainActor
    static let liveValue =
        RadioStore()

    @MainActor
    static let previewValue =
        RadioStore()

    @MainActor
    static let testValue =
        RadioStore()
}


// MARK: - Playlist Store Key

private enum PlaylistStoreDependencyKey:
    DependencyKey {

    @MainActor
    static let liveValue =
        PlaylistStore()

    @MainActor
    static let previewValue =
        PlaylistStore()

    @MainActor
    static let testValue =
        PlaylistStore()
}

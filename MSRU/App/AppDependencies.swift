//
//  AppDependencies.swift
//  MSRU
//

import Foundation
import AppFoundation


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
            in AppState and inject it through DependencyValues.
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
            in AppState and inject it through DependencyValues.
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
}

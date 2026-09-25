//
//  MSRUPreviewData.swift
//  MSRU
//

import Foundation
import MusicKit
import AppFoundation
import MusicLibrary
import MusicPlayback
import SubsonicKit

// MARK: - Preview Data

enum MSRUPreviewData {
    static let openverseOne = OpenverseAudio(
        id: "preview-openverse-1",
        title: "Morning Field Recording",
        creator: "Preview Artist",
        mediaURLString: "file:///tmp/msru-preview-audio-1.mp3",
        durationMilliseconds: 184_000,
        filetype: "mp3",
        provider: "wikimedia",
        source: "openverse",
        license: "cc0",
        licenseVersion: "1.0",
        descriptionText: "A quiet field recording used by the local preview environment."
    )

    static let openverseTwo = OpenverseAudio(
        id: "preview-openverse-2",
        title: "Piano Study No. 4",
        creator: "Mira Vale",
        mediaURLString: "file:///tmp/msru-preview-audio-2.mp3",
        durationMilliseconds: 256_000,
        filetype: "mp3",
        provider: "jamendo",
        source: "openverse",
        license: "by",
        licenseVersion: "4.0",
        descriptionText: "Openly licensed piano recording."
    )

    static let openverseThree = OpenverseAudio(
        id: "preview-openverse-3",
        title: "Signals After Rain",
        creator: "Northbound",
        mediaURLString: "file:///tmp/msru-preview-audio-3.mp3",
        durationMilliseconds: 221_000,
        filetype: "m4a",
        provider: "freesound",
        source: "openverse",
        license: "by-sa",
        licenseVersion: "4.0",
        descriptionText: "Ambient recording with a deliberately longer description for layout testing."
    )

    static let openverseFour = OpenverseAudio(
        id: "preview-openverse-4",
        title: "A Very Long Recording Title Used to Test the Browse Card Layout",
        creator: nil,
        mediaURLString: "file:///tmp/msru-preview-audio-4.mp3",
        durationMilliseconds: 95_000,
        filetype: "wav",
        provider: "internet_archive",
        source: "openverse",
        license: "cc0"
    )

    static let openverseResults: [OpenverseAudio] = [
        openverseOne,
        openverseTwo,
        openverseThree,
        openverseFour
    ]

    @MainActor
    static func makeBrowseFeature() -> FeatureHost<BrowseFeature> {
        let webLibrary = WebLibraryStore(db: try! AppDatabase.makeEphemeral())
        let playback = makePlaybackController()
        let state = BrowseFeature.State(query: "preview", results: openverseResults)

        var dependencies = DependencyValues.preview
        dependencies.openverseSearch = .preview(results: openverseResults)
        dependencies.playback = playback
        dependencies.webLibrary = webLibrary

        return withDependencies(dependencies) {
            FeatureHost<BrowseFeature>(state: state, service: BrowseFeature.Service())
        }
    }

    @MainActor
    static func makeRadioFeature() -> FeatureHost<RadioFeature> {
        let scene = makeScene(section: .radio)
        return scene.radioFeature
    }

    static let localTracks = [
        LocalTrack(
            fileURL: URL(fileURLWithPath: "/preview/Northern Lights.m4a"),
            title: "Northern Lights",
            artist: "Aurora Ensemble",
            album: "Night Studies",
            duration: 184,
            artworkData: nil
        ),
        LocalTrack(
            fileURL: URL(fileURLWithPath: "/preview/Quiet Geometry.mp3"),
            title: "Quiet Geometry",
            artist: "Mira Vale",
            album: nil,
            duration: 256,
            artworkData: nil
        )
    ]

    @MainActor
    static func makeLocalLibraryStore(empty: Bool = false) -> LocalLibraryStore {
        LocalLibraryStore(repository: PreviewLocalLibraryRepository(tracks: empty ? [] : localTracks))
    }

    @MainActor
    static func makeAppleMusicStore() -> AppleMusicLibraryStore {
        AppleMusicLibraryStore(service: PreviewAppleMusicService(), authorizationStatus: .notDetermined)
    }

    @MainActor
    static func makePlaybackController() -> PlaybackController {
        PlaybackController(providerKernel: PlaybackProviderKernel(registry: ProviderRegistry()))
    }

    @MainActor
    static func makePlaylistStore() -> PlaylistStore {
        PlaylistStore(repository: PreviewPlaylistRepository(playlists: [
            Playlist(
                title: "Favorites",
                description: "Your hand-picked top tracks",
                trackIDs: localTracks.prefix(3).map(\.id),
                isPinned: true
            ),
            Playlist(
                title: "Night Drive Vibes",
                description: "Late night atmospheric synthwave and ambient beats",
                trackIDs: localTracks.suffix(2).map(\.id)
            )
        ]))
    }

    @MainActor
    static func makeApplication() -> ApplicationModel {
        ApplicationModel(
            localLibrary: makeLocalLibraryStore(),
            webLibrary: WebLibraryStore(db: try! AppDatabase.makeEphemeral()),
            musicLibrary: makeAppleMusicStore(),
            playback: makePlaybackController(),
            services: .isolated(),
            openverseSearch: .preview(results: openverseResults),
            playlistStore: makePlaylistStore(),
            subsonicServers: SubsonicServerStore(coordinator: .preview())
        )
    }

    @MainActor
    static func makeScene(section: SceneSection = .listenNow) -> SceneModel {
        SceneModel(application: makeApplication(), section: section)
    }
}

@MainActor
private struct PreviewLocalLibraryRepository: LocalLibraryRepository {
    let tracks: [LocalTrack]
    func loadTracks() async throws -> [LocalTrack] { tracks }
    func importTrack(from url: URL) async throws -> LocalTrack? {
        throw PreviewImportError.unavailable
    }
}

private enum PreviewImportError: LocalizedError {
    case unavailable
    var errorDescription: String? { "File import is unavailable in previews." }
}

@MainActor
private struct PreviewAppleMusicService: AppleMusicLibraryServing {
    func requestAuthorization() async -> MusicAuthorization.Status { .denied }
    func fetchAlbums() async throws -> [Album] { [] }
    func fetchArtists() async throws -> [Artist] { [] }
    func fetchSongs() async throws -> [Song] { [] }
}

extension SourceRuntimeCoordinator {
    /// Isolated coordinator for previews: in-memory database, credentials and defaults.
    static func preview() -> SourceRuntimeCoordinator {
        SourceRuntimeCoordinator(
            db: try! AppDatabase.makeEphemeral(),
            credentialStore: InMemorySubsonicCredentialStore(),
            legacyDefaults: UserDefaults(suiteName: "msru.preview.\(UUID().uuidString)")!
        )
    }
}

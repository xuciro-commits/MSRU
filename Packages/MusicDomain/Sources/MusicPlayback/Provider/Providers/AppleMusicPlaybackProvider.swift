//
//  AppleMusicPlaybackProvider.swift
//  MSRU
//

import Foundation
import MusicKit
import MusicDomain
import MusicLibrary

// MARK: - Apple Music Playback Provider

/// Resolves Apple Music catalog items for playback via MusicKit's `ApplicationMusicPlayer`.
///
/// When the controller activates a `.providerNative(.appleMusic, …)` resource,
/// it delegates play/pause/seek to the shared `ApplicationMusicPlayer` instance
/// rather than managing an `AVPlayer` or PCM engine directly.
public struct AppleMusicPlaybackProvider: PlaybackProvider {

    public let id: PlaybackProviderID = .appleMusic
    public let priority = 1_100

    public func canResolve(_ request: PlaybackRequest) -> Bool {
        request.source == .appleMusic && !request.itemID.isEmpty
    }

    public func resolve(_ request: PlaybackRequest) async throws -> PlaybackResource {
        try Task.checkCancellation()

        let catalogID = request.itemID

        // Try library first (user's own Apple Music library), then catalog.
        let song = try await lookupSong(catalogID: catalogID)

        guard let song else {
            throw AppleMusicPlaybackError.songNotFound(catalogID: catalogID)
        }

        let player = ApplicationMusicPlayer.shared
        player.queue = [song]

        return PlaybackResource(
            providerID: .appleMusic,
            transport: .providerNative(providerID: .appleMusic, token: catalogID),
            duration: song.duration
        )
    }

    // MARK: - Lookup

    private func lookupSong(catalogID: String) async throws -> Song? {
        // 1. Try the user's library first (imported tracks).
        var libraryRequest = MusicLibraryRequest<Song>()
        libraryRequest.filter(matching: \.id, equalTo: MusicItemID(catalogID))
        let libraryResponse = try await libraryRequest.response()
        if let match = libraryResponse.items.first {
            return match
        }

        // 2. Fall back to catalog search by ID.
        let catalogRequest = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(catalogID))
        let catalogResponse = try await catalogRequest.response()
        return catalogResponse.items.first
    }

    nonisolated public init() {}
}

// MARK: - Errors

private enum AppleMusicPlaybackError: LocalizedError {
    case songNotFound(catalogID: String)

    public var errorDescription: String? {
        switch self {
        case .songNotFound(let catalogID):
            return "Apple Music song with ID \(catalogID) was not found in your library or catalog."
        }
    }
}

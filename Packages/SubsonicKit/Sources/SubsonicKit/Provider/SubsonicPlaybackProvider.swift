//
//  SubsonicPlaybackProvider.swift
//  SubsonicKit
//
//  Resolves remote Subsonic tracks into streaming URLs with ephemeral credentials.
//

import Foundation
import MediaLibrary

public final class SubsonicPlaybackProvider: Sendable {
    public let sourceID: LibrarySourceID
    public let client: SubsonicClient

    public init(sourceID: LibrarySourceID, client: SubsonicClient) {
        self.sourceID = sourceID
        self.client = client
    }

    /// Resolves on-demand playback URL with fresh authenticated token without persisting credentials.
    public func resolveStreamURL(for rawTrackID: String, format: String? = nil, maxBitRate: Int? = nil) async throws -> URL {
        try client.streamURL(id: rawTrackID, format: format, maxBitRate: maxBitRate)
    }

    @available(*, deprecated, message: "Use resolveStreamURL(for:format:maxBitRate:) instead.")
    public func resolveStreamURL(for rawTrackID: String, raw: Bool) async throws -> URL {
        try client.streamURL(id: rawTrackID, format: raw ? "raw" : nil)
    }
}

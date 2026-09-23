//
//  SubsonicCapabilityProbe.swift
//  SubsonicKit
//
//  Probes a remote Subsonic/OpenSubsonic server and resolves dynamic capabilities.
//

import Foundation
import MediaLibrary

public struct SubsonicCapabilityProbe: Sendable {
    public init() {}

    public func probe(client: SubsonicClient) async throws -> (info: SubsonicServerInfo, capabilities: LibraryCapabilities) {
        let info = try await client.ping()

        var caps: LibraryCapabilities = [
            .browse,
            .search,
            .artwork,
            .streaming,
            .ratings
        ]

        if info.isOpenSubsonic {
            caps.insert(.openSubsonicExtensions)
        }

        // OpenSubsonic extensions checks
        let extNames = Set(info.openSubsonicExtensions.map(\.name))
        if extNames.contains("transcodeFree") || extNames.contains("raw") {
            caps.insert(.streaming)
        }
        if extNames.contains("lyrics") {
            caps.insert(.lyrics)
        }

        // Standard capabilities usually available on Subsonic >= 1.14
        caps.insert(.playlistsRead)
        caps.insert(.playlistsWrite)
        caps.insert(.favoritesRead)
        caps.insert(.favoritesWrite)
        caps.insert(.scrobbling)
        caps.insert(.downloading)

        return (info, caps)
    }
}

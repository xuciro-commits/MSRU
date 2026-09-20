//
//  Playlist.swift
//  MSRU
//

import Foundation

public struct Playlist: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var description: String?
    public var trackIDs: [String]
    public var artworkData: Data?
    public var isPinned: Bool
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        trackIDs: [String] = [],
        artworkData: Data? = nil,
        isPinned: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.trackIDs = trackIDs
        self.artworkData = artworkData
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var trackCount: Int {
        trackIDs.count
    }
}

// MARK: - Playlist Repository

protocol PlaylistRepository: Sendable {
    func loadPlaylists() async throws -> [Playlist]
    func savePlaylists(_ playlists: [Playlist]) async throws
}

final class JSONPlaylistRepository: PlaylistRepository, @unchecked Sendable {
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let msruDir = appSupport.appendingPathComponent("com.msru.cn.MSRU", isDirectory: true)
            try? FileManager.default.createDirectory(at: msruDir, withIntermediateDirectories: true)
            self.fileURL = msruDir.appendingPathComponent("playlists.json")
        }
    }

    func loadPlaylists() async throws -> [Playlist] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([Playlist].self, from: data)
    }

    func savePlaylists(_ playlists: [Playlist]) async throws {
        let data = try JSONEncoder().encode(playlists)
        try data.write(to: fileURL, options: .atomic)
    }
}

final class PreviewPlaylistRepository: PlaylistRepository, @unchecked Sendable {
    private var playlists: [Playlist]

    init(playlists: [Playlist] = []) {
        self.playlists = playlists
    }

    func loadPlaylists() async throws -> [Playlist] {
        playlists
    }

    func savePlaylists(_ playlists: [Playlist]) async throws {
        self.playlists = playlists
    }
}

//
//  WatchedFolder.swift
//  MSRU
//
//  Created for Task 31: Watched Folders background monitoring and continuous ingestion.
//

import Foundation

/// A directory configured for continuous background file monitoring and ingestion.
public struct WatchedFolder: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var url: URL
    public var bookmarkData: Data?
    public var isEnabled: Bool
    public var autoIngest: Bool
    public var lastScannedAt: Date?
    public var trackCount: Int

    public init(
        id: UUID = UUID(),
        url: URL,
        bookmarkData: Data? = nil,
        isEnabled: Bool = true,
        autoIngest: Bool = true,
        lastScannedAt: Date? = nil,
        trackCount: Int = 0
    ) {
        self.id = id
        self.url = url
        self.bookmarkData = bookmarkData
        self.isEnabled = isEnabled
        self.autoIngest = autoIngest
        self.lastScannedAt = lastScannedAt
        self.trackCount = trackCount
    }

    public var displayName: String {
        url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
    }

    public var path: String {
        url.path
    }

    public var isNetworkVolume: Bool {
        !SecurityScopePolicy.isLocalVolume(url)
    }
}

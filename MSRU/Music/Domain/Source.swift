//
//  Source.swift
//  MSRU
//
//  Source abstraction defining capabilities rather than UI types.
//

import Foundation

public enum SourceType: String, Codable, Sendable, CaseIterable {
    case localFolder = "local_folder"
    case networkFolder = "network_folder"
    case futureProvider = "future_provider"
}

nonisolated public struct SourceCapabilities: OptionSet, Codable, Sendable, Hashable {
    public let rawValue: Int

    nonisolated public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let supportsChangeEvents       = SourceCapabilities(rawValue: 1 << 0)
    public static let supportsRecursiveScan      = SourceCapabilities(rawValue: 1 << 1)
    public static let supportsRandomAccess       = SourceCapabilities(rawValue: 1 << 2)
    public static let supportsStreaming          = SourceCapabilities(rawValue: 1 << 3)
    public static let supportsMetadataWrite      = SourceCapabilities(rawValue: 1 << 4)
    public static let supportsDelete             = SourceCapabilities(rawValue: 1 << 5)
    public static let supportsMove               = SourceCapabilities(rawValue: 1 << 6)
    public static let supportsArtwork            = SourceCapabilities(rawValue: 1 << 7)
    public static let supportsStableExternalID   = SourceCapabilities(rawValue: 1 << 8)

    public static let localFolderDefault: SourceCapabilities = [
        .supportsChangeEvents,
        .supportsRecursiveScan,
        .supportsRandomAccess,
        .supportsMetadataWrite,
        .supportsDelete,
        .supportsMove,
        .supportsArtwork,
        .supportsStableExternalID
    ]

    public static let networkFolderDefault: SourceCapabilities = [
        .supportsRecursiveScan,
        .supportsRandomAccess,
        .supportsArtwork,
        .supportsStableExternalID
    ]
}

nonisolated public struct Source: Identifiable, Hashable, Codable, Sendable {
    public let id: SourceID
    public var sourceType: SourceType
    public var uri: String
    public var displayName: String
    public var capabilities: SourceCapabilities
    public var isEnabled: Bool
    public var lastReconciledAt: Date?
    public var bookmarkData: Data?
    public let createdAt: Date
    public var updatedAt: Date

    nonisolated public init(
        id: SourceID = .generate(),
        sourceType: SourceType,
        uri: String,
        displayName: String,
        capabilities: SourceCapabilities,
        isEnabled: Bool = true,
        lastReconciledAt: Date? = nil,
        bookmarkData: Data? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sourceType = sourceType
        self.uri = uri
        self.displayName = displayName
        self.capabilities = capabilities
        self.isEnabled = isEnabled
        self.lastReconciledAt = lastReconciledAt
        self.bookmarkData = bookmarkData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

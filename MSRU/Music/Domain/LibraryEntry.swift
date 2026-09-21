//
//  LibraryEntry.swift
//  MSRU
//
//  User library state representation.
//

import Foundation

nonisolated public struct LibraryEntry: Identifiable, Hashable, Codable, Sendable {
    public let id: LibraryEntryID
    public let recordingID: RecordingID
    public let releaseTrackID: ReleaseTrackID?
    public var isFavorite: Bool
    public var rating: Int
    public var playCount: Int
    public var lastPlayedAt: Date?
    public let dateAdded: Date

    nonisolated public init(
        id: LibraryEntryID = .generate(),
        recordingID: RecordingID,
        releaseTrackID: ReleaseTrackID? = nil,
        isFavorite: Bool = false,
        rating: Int = 0,
        playCount: Int = 0,
        lastPlayedAt: Date? = nil,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.recordingID = recordingID
        self.releaseTrackID = releaseTrackID
        self.isFavorite = isFavorite
        self.rating = rating
        self.playCount = playCount
        self.lastPlayedAt = lastPlayedAt
        self.dateAdded = dateAdded
    }
}

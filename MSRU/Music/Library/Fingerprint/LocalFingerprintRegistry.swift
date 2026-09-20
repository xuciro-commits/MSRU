//
//  LocalFingerprintRegistry.swift
//  MSRU
//
//  Created for Local Acoustic Fingerprint Memory & Disambiguation.
//

import Foundation
import Observation

/// A locally learned acoustic fingerprint association.
nonisolated public struct AcousticFingerprintRecord: Identifiable, Codable, Sendable, Equatable {
    public var id: String { fingerprint }
    public let fingerprint: String
    public let duration: TimeInterval
    public var title: String
    public var artist: String
    public var album: String?
    public var trackNumber: Int?
    public var releaseMBID: String?
    public var recordingMBID: String?
    public var artworkData: Data?
    public let dateLearned: Date
    public var matchCount: Int

    public init(
        fingerprint: String,
        duration: TimeInterval,
        title: String,
        artist: String,
        album: String? = nil,
        trackNumber: Int? = nil,
        releaseMBID: String? = nil,
        recordingMBID: String? = nil,
        artworkData: Data? = nil,
        dateLearned: Date = Date(),
        matchCount: Int = 1
    ) {
        self.fingerprint = fingerprint
        self.duration = duration
        self.title = title
        self.artist = artist
        self.album = album
        self.trackNumber = trackNumber
        self.releaseMBID = releaseMBID
        self.recordingMBID = recordingMBID
        self.artworkData = artworkData
        self.dateLearned = dateLearned
        self.matchCount = matchCount
    }
}

/// Central registry managing lightweight local acoustic fingerprint memory.
@MainActor
@Observable
public final class LocalFingerprintRegistry {
    public static let shared = LocalFingerprintRegistry()

    public private(set) var records: [AcousticFingerprintRecord] = []
    private let storageURL: URL

    public init(storageURL: URL? = nil) {
        if let storageURL {
            self.storageURL = storageURL
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let dir = support.appendingPathComponent("MSRU/Fingerprints", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.storageURL = dir.appendingPathComponent("local_fingerprints.json")
        }
        load()
    }

    /// Fast lookup by exact fingerprint or duration proximity.
    public func lookup(fingerprint: String, duration: TimeInterval, tolerance: TimeInterval = 2.0) -> AcousticFingerprintRecord? {
        // 1. Exact fingerprint match
        if let exact = records.first(where: { $0.fingerprint == fingerprint }) {
            return exact
        }

        // 2. Duration proximity match if duration matches closely
        for record in records {
            if abs(record.duration - duration) <= tolerance && record.fingerprint == fingerprint {
                return record
            }
        }

        return nil
    }

    /// Registers or updates a local fingerprint memory record.
    public func register(
        fingerprint: String,
        duration: TimeInterval,
        title: String,
        artist: String,
        album: String? = nil,
        trackNumber: Int? = nil,
        releaseMBID: String? = nil,
        recordingMBID: String? = nil,
        artworkData: Data? = nil
    ) {
        if let idx = records.firstIndex(where: { $0.fingerprint == fingerprint }) {
            records[idx].matchCount += 1
            records[idx].title = title
            records[idx].artist = artist
            if let album { records[idx].album = album }
            if let releaseMBID { records[idx].releaseMBID = releaseMBID }
            if let recordingMBID { records[idx].recordingMBID = recordingMBID }
            if let artworkData { records[idx].artworkData = artworkData }
        } else {
            let record = AcousticFingerprintRecord(
                fingerprint: fingerprint,
                duration: duration,
                title: title,
                artist: artist,
                album: album,
                trackNumber: trackNumber,
                releaseMBID: releaseMBID,
                recordingMBID: recordingMBID,
                artworkData: artworkData
            )
            records.append(record)
        }
        save()
    }

    /// Removes a record by fingerprint.
    public func remove(fingerprint: String) {
        records.removeAll { $0.fingerprint == fingerprint }
        save()
    }

    /// Clears all local fingerprint memory.
    public func removeAll() {
        records.removeAll()
        save()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path),
              let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([AcousticFingerprintRecord].self, from: data) else {
            return
        }
        self.records = decoded
    }

    private func save() {
        guard let encoded = try? JSONEncoder().encode(records) else { return }
        try? encoded.write(to: storageURL, options: .atomic)
    }
}

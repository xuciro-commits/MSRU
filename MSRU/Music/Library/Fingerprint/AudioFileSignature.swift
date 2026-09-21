//
//  AudioFileSignature.swift
//  MSRU
//
//  Created for Audio File Cache Validation Heuristic.
//

import Foundation

/// A lightweight heuristic signature of an audio file on disk used exclusively
/// for cache-invalidation decisions.
///
/// Note: This signature reflects physical file metadata (size, modification time, canonical path)
/// and serves as a fast validation heuristic; it does NOT assert cryptographic proof of content identity.
nonisolated public struct AudioFileSignature: Hashable, Sendable, Codable {

    public static let currentSchemaVersion = 1

    public let canonicalPath: String
    public let fileSize: Int64
    public let modificationTime: TimeInterval
    public let schemaVersion: Int

    public init(
        canonicalPath: String,
        fileSize: Int64,
        modificationTime: TimeInterval,
        schemaVersion: Int = currentSchemaVersion
    ) {
        self.canonicalPath = canonicalPath
        self.fileSize = fileSize
        self.modificationTime = modificationTime
        self.schemaVersion = schemaVersion
    }

    /// Creates a signature by inspecting the attributes of the item at the given file URL.
    public init?(fileURL: URL) {
        let canonical = fileURL.resolvingSymlinksInPath().standardizedFileURL.path
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: canonical),
              let size = attrs[.size] as? Int64,
              let mdate = attrs[.modificationDate] as? Date else {
            return nil
        }
        self.canonicalPath = canonical
        self.fileSize = size
        self.modificationTime = mdate.timeIntervalSince1970
        self.schemaVersion = Self.currentSchemaVersion
    }

    /// Fast validation check against the current filesystem state of the given URL.
    public func matches(fileURL: URL, tolerance: TimeInterval = 1.0) -> Bool {
        guard let current = AudioFileSignature(fileURL: fileURL) else { return false }
        return current.canonicalPath == self.canonicalPath &&
               current.fileSize == self.fileSize &&
               abs(current.modificationTime - self.modificationTime) < tolerance
    }
}

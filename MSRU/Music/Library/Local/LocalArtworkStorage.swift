//
//  LocalArtworkStorage.swift
//  MSRU
//
//  Created for Decoupled Content-Addressable Artwork Storage.
//

import Foundation
import CryptoKit

/// Content-addressable disk storage for artwork images, decoupling raw image blobs
/// from track metadata manifests (such as external_tracks.json).
nonisolated public final class LocalArtworkStorage: Sendable {

    nonisolated public static let shared = LocalArtworkStorage()

    private let baseDirectory: URL

    public init(baseDirectory: URL? = nil) {
        if let baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.baseDirectory = support.appendingPathComponent("MSRU/LocalMedia/Artworks", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.baseDirectory, withIntermediateDirectories: true)
    }

    /// Saves artwork data to content-addressed storage (SHA256 filename) and returns its relative path.
    /// Idempotent: writing the same image multiple times produces the exact same file without duplication.
    public func storeArtwork(_ data: Data) -> String? {
        guard !data.isEmpty else { return nil }

        let digest = SHA256.hash(data: data)
        let hashString = digest.compactMap { String(format: "%02x", $0) }.joined()
        let filename = "\(hashString).jpg"
        let fileURL = baseDirectory.appendingPathComponent(filename)

        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try? data.write(to: fileURL, options: .atomic)
        }

        return "Artworks/\(filename)"
    }

    /// Loads raw artwork data given a relative storage path (e.g. "Artworks/abcd1234.jpg").
    public func loadArtwork(relativePath: String) -> Data? {
        let cleanRelative = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanRelative.isEmpty else { return nil }

        let fileURL: URL
        if cleanRelative.hasPrefix("Artworks/") {
            let filename = String(cleanRelative.dropFirst("Artworks/".count))
            fileURL = baseDirectory.appendingPathComponent(filename)
        } else {
            fileURL = baseDirectory.appendingPathComponent(cleanRelative)
        }

        return try? Data(contentsOf: fileURL)
    }

    /// Removes an artwork file from storage.
    public func removeArtwork(relativePath: String) {
        let cleanRelative = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanRelative.isEmpty else { return }

        let fileURL: URL
        if cleanRelative.hasPrefix("Artworks/") {
            let filename = String(cleanRelative.dropFirst("Artworks/".count))
            fileURL = baseDirectory.appendingPathComponent(filename)
        } else {
            fileURL = baseDirectory.appendingPathComponent(cleanRelative)
        }

        try? FileManager.default.removeItem(at: fileURL)
    }
}

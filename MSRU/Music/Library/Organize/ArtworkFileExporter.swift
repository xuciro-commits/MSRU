//
//  ArtworkFileExporter.swift
//  MSRU
//
//  Created for Acoustic Metadata Pipeline Architecture Phase 4.
//

import Foundation

/// Service for exporting companion artwork files (cover.jpg) alongside music files.
public struct ArtworkFileExporter: Sendable {

    public init() {}

    /// Exports cover artwork to the designated folder URL as `cover.jpg`.
    ///
    /// - Parameters:
    ///   - artworkData: Raw JPEG/PNG image binary data.
    ///   - folderURL: The directory where the album resides.
    ///   - overwrite: If false, skips if `cover.jpg` already exists.
    /// - Returns: URL of the exported cover file if successful, or nil.
    @discardableResult
    public static func exportCover(
        artworkData: Data?,
        to folderURL: URL,
        overwrite: Bool = false
    ) -> URL? {
        guard let data = artworkData, !data.isEmpty else { return nil }

        let coverURL = folderURL.appendingPathComponent("cover.jpg")
        if FileManager.default.fileExists(atPath: coverURL.path) && !overwrite {
            return coverURL
        }

        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            try data.write(to: coverURL, options: .atomic)
            return coverURL
        } catch {
            return nil
        }
    }
}

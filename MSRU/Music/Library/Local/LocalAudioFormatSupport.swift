//
//  LocalAudioFormatSupport.swift
//  MSRU
//

import Foundation
import UniformTypeIdentifiers


nonisolated enum LocalAudioFormatSupport {

    // MARK: - Extensions

    static let supportedExtensions: Set<String> = [
        "mp3",
        "m4a",
        "aac",
        "wav",
        "aif",
        "aiff",
        "caf",
        "flac",
        "mp4",
        "dts",
        "dsd",
        "dsf",
        "dff",
        "alac",
        "ogg",
        "opus",
        "ape",
        "wv",
        "wma"
    ]

    // MARK: - Import Types

    static var importContentTypes: [UTType] {
        var types: [UTType] = [.audio, .folder]

        for ext in supportedExtensions {
            if let type = UTType(filenameExtension: ext) {
                if !types.contains(type) {
                    types.append(type)
                }
            } else if let type = UTType(filenameExtension: ext, conformingTo: .data) {
                if !types.contains(type) {
                    types.append(type)
                }
            }
        }

        return types
    }

    // MARK: - Support

    static func supports(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    static func supports(extension ext: String) -> Bool {
        supportedExtensions.contains(ext.lowercased())
    }

    // MARK: - Native Apple Formats
    static let nativeAppleExtensions: Set<String> = [
        "mp3",
        "m4a",
        "aac",
        "wav",
        "aif",
        "aiff",
        "caf",
        "flac",
        "alac",
        "mp4"
    ]

    static func isNativeAppleFormat(_ url: URL) -> Bool {
        nativeAppleExtensions.contains(url.pathExtension.lowercased())
    }

    static func isNativeAppleFormat(extension ext: String) -> Bool {
        nativeAppleExtensions.contains(ext.lowercased())
    }

    static func isDTS(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "dts"
    }
}

// MARK: - DSF Header Reader

nonisolated public struct DSFMetadata: Sendable {
    public let sampleRate: Double
    public let channelCount: Int
    public let sampleCount: UInt64
    public let duration: TimeInterval
}

nonisolated public enum DSFHeaderReader {
    /// Reads the basic metadata (duration, sample rate, channels) directly from a DSF file header.
    public static func readMetadata(from url: URL) -> DSFMetadata? {
        let hasScope = url.startAccessingSecurityScopedResource()
        defer {
            if hasScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return nil
        }
        defer {
            try? handle.close()
        }

        guard let headerData = try? handle.read(upToCount: 80), headerData.count >= 72 else {
            return nil
        }

        // Verify "DSD " magic at offset 0
        guard headerData[0] == 0x44, headerData[1] == 0x53, headerData[2] == 0x44, headerData[3] == 0x20 else {
            return nil
        }

        // Verify "fmt " magic at offset 28
        guard headerData[28] == 0x66, headerData[29] == 0x6D, headerData[30] == 0x74, headerData[31] == 0x20 else {
            return nil
        }

        // Channel count: UInt32 at offset 52
        let channels = headerData.subdata(in: 52..<56).withUnsafeBytes {
            $0.load(as: UInt32.self)
        }

        // Sample rate: UInt32 at offset 56
        let sampleRate = headerData.subdata(in: 56..<60).withUnsafeBytes {
            $0.load(as: UInt32.self)
        }

        // Sample count: UInt64 at offset 64
        let sampleCount = headerData.subdata(in: 64..<72).withUnsafeBytes {
            $0.load(as: UInt64.self)
        }

        guard sampleRate > 0 else { return nil }
        let duration = Double(sampleCount) / Double(sampleRate)

        return DSFMetadata(
            sampleRate: Double(sampleRate),
            channelCount: Int(channels),
            sampleCount: sampleCount,
            duration: duration
        )
    }
}


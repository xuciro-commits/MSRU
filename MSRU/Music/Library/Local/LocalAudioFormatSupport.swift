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
    public let title: String?
    public let artist: String?
    public let album: String?
    public let trackNumber: Int?
    public let year: Int?
    public let artworkData: Data?

    public init(
        sampleRate: Double,
        channelCount: Int,
        sampleCount: UInt64,
        duration: TimeInterval,
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        trackNumber: Int? = nil,
        year: Int? = nil,
        artworkData: Data? = nil
    ) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.sampleCount = sampleCount
        self.duration = duration
        self.title = title
        self.artist = artist
        self.album = album
        self.trackNumber = trackNumber
        self.year = year
        self.artworkData = artworkData
    }
}

nonisolated public enum DSFHeaderReader {
    /// Reads the audio metadata (duration, sample rate, channels, and ID3 tags) directly from a DSF file header and metadata chunk.
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

        // File size at offset 12 (UInt64)
        let fileSize = headerData.subdata(in: 12..<20).withUnsafeBytes {
            $0.load(as: UInt64.self)
        }

        // Metadata offset at offset 20 (UInt64)
        let metadataOffset = headerData.subdata(in: 20..<28).withUnsafeBytes {
            $0.load(as: UInt64.self)
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

        // Read and parse ID3v2 metadata chunk if present
        var parsedTitle: String? = nil
        var parsedArtist: String? = nil
        var parsedAlbum: String? = nil
        var parsedTrackNumber: Int? = nil
        var parsedYear: Int? = nil
        var parsedArtworkData: Data? = nil

        if metadataOffset > 0, metadataOffset < fileSize {
            do {
                try handle.seek(toOffset: metadataOffset)
                let maxMetaSize = min(fileSize - metadataOffset, 16 * 1024 * 1024) // 16MB safety cap
                if let metaBytes = try? handle.read(upToCount: Int(maxMetaSize)), metaBytes.count >= 10 {
                    let parsed = parseID3v2(data: metaBytes)
                    parsedTitle = parsed.title
                    parsedArtist = parsed.artist
                    parsedAlbum = parsed.album
                    parsedTrackNumber = parsed.trackNumber
                    parsedYear = parsed.year
                    parsedArtworkData = parsed.artworkData
                }
            } catch {
                // Non-fatal
            }
        }

        return DSFMetadata(
            sampleRate: Double(sampleRate),
            channelCount: Int(channels),
            sampleCount: sampleCount,
            duration: duration,
            title: parsedTitle,
            artist: parsedArtist,
            album: parsedAlbum,
            trackNumber: parsedTrackNumber,
            year: parsedYear,
            artworkData: parsedArtworkData
        )
    }

    private static func parseID3v2(data: Data) -> (
        title: String?,
        artist: String?,
        album: String?,
        trackNumber: Int?,
        year: Int?,
        artworkData: Data?
    ) {
        guard data.count >= 10,
              data[0] == 0x49, data[1] == 0x44, data[2] == 0x33 else { // "ID3"
            return (nil, nil, nil, nil, nil, nil)
        }
        let versionMajor = data[3]
        let tagSize = (Int(data[6] & 0x7F) << 21) | (Int(data[7] & 0x7F) << 14) | (Int(data[8] & 0x7F) << 7) | Int(data[9] & 0x7F)
        let limit = min(data.count, 10 + tagSize)
        var offset = 10

        var title: String?
        var artist: String?
        var album: String?
        var trackNumber: Int?
        var year: Int?
        var artworkData: Data?

        while offset + 10 <= limit {
            let idBytes = data.subdata(in: offset..<offset+4)
            if idBytes[0] == 0 { break } // Padding reached
            guard let frameID = String(data: idBytes, encoding: .isoLatin1) else { break }

            let frameSize: Int
            if versionMajor == 4 {
                frameSize = (Int(data[offset+4] & 0x7F) << 21) | (Int(data[offset+5] & 0x7F) << 14) | (Int(data[offset+6] & 0x7F) << 7) | Int(data[offset+7] & 0x7F)
            } else {
                frameSize = (Int(data[offset+4]) << 24) | (Int(data[offset+5]) << 16) | (Int(data[offset+6]) << 8) | Int(data[offset+7])
            }

            offset += 10
            guard frameSize > 0, offset + frameSize <= data.count else { break }
            let payload = data.subdata(in: offset..<offset+frameSize)
            offset += frameSize

            func decodeText(_ d: Data) -> String? {
                guard !d.isEmpty else { return nil }
                let enc = d[0]
                let textData = d.dropFirst()
                let str: String?
                switch enc {
                case 0: str = String(data: textData, encoding: .isoLatin1)
                case 1: str = String(data: textData, encoding: .utf16)
                case 2: str = String(data: textData, encoding: .utf16BigEndian)
                case 3: str = String(data: textData, encoding: .utf8)
                default: str = String(data: textData, encoding: .utf8)
                }
                return str?.trimmingCharacters(in: CharacterSet(charactersIn: "\0 \t\n\r"))
            }

            switch frameID {
            case "TIT2":
                title = decodeText(payload)
            case "TPE1":
                artist = decodeText(payload)
            case "TALB":
                album = decodeText(payload)
            case "TRCK":
                if let str = decodeText(payload) {
                    let digits = str.prefix(while: { $0.isNumber })
                    if let num = Int(digits) {
                        trackNumber = num
                    }
                }
            case "TYER", "TDRC":
                if let str = decodeText(payload) {
                    let digits = str.prefix(while: { $0.isNumber })
                    if digits.count >= 4, let yr = Int(digits.prefix(4)) {
                        year = yr
                    }
                }
            case "APIC":
                guard payload.count > 5 else { break }
                let enc = payload[0]
                var pos = 1
                // Skip MIME type (null terminated)
                while pos < payload.count && payload[pos] != 0 { pos += 1 }
                pos += 1 // Skip null byte
                if pos < payload.count {
                    // Skip picture type (1 byte)
                    pos += 1
                    // Skip description (null terminated according to encoding)
                    if enc == 1 || enc == 2 {
                        while pos + 1 < payload.count && !(payload[pos] == 0 && payload[pos+1] == 0) {
                            pos += 2
                        }
                        pos += 2
                    } else {
                        while pos < payload.count && payload[pos] != 0 {
                            pos += 1
                        }
                        pos += 1
                    }
                    if pos < payload.count {
                        let picBytes = payload.subdata(in: pos..<payload.count)
                        if picBytes.count >= 4 {
                            artworkData = picBytes
                        }
                    }
                }
            default:
                break
            }
        }

        return (title, artist, album, trackNumber, year, artworkData)
    }
}


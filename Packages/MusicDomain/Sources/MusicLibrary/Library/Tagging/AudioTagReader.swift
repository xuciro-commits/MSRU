//
//  AudioTagReader.swift
//  MSRU
//
//  Created for Professional Music Library Management.
//

import Foundation
import AVFoundation
import MusicDomain

nonisolated public struct AudioTechnicalSpecs: Sendable, Equatable {
    public let formatName: String
    public let sampleRate: Double
    public let bitDepth: Int?
    public let channelCount: Int
    public let duration: TimeInterval
    public let fileSize: Int64
    public let bitrate: Int? // kbps

    nonisolated public init(
        formatName: String,
        sampleRate: Double,
        bitDepth: Int? = nil,
        channelCount: Int,
        duration: TimeInterval,
        fileSize: Int64,
        bitrate: Int? = nil
    ) {
        self.formatName = formatName
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.channelCount = channelCount
        self.duration = duration
        self.fileSize = fileSize
        self.bitrate = bitrate
    }

    nonisolated public var formattedSampleRate: String {
        if sampleRate >= 1000 {
            return String(format: "%.1f kHz", sampleRate / 1000.0)
        } else {
            return "\(Int(sampleRate)) Hz"
        }
    }

    nonisolated public var channelLayoutDescription: String {
        switch channelCount {
        case 1: return "Mono (1.0)"
        case 2: return "Stereo (2.0)"
        case 6: return "5.1 Surround"
        case 8: return "7.1 Surround"
        default: return "\(channelCount) Channels"
        }
    }

    nonisolated public var formattedBitDepth: String {
        if let bitDepth {
            return "\(bitDepth)-bit"
        }
        return "Standard"
    }

    nonisolated public var formattedBitrate: String {
        if let bitrate {
            return "\(bitrate) kbps"
        }
        return "Unknown"
    }

    nonisolated public var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    nonisolated public var formattedDuration: String {
        let total = Int(duration)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

nonisolated public struct AudioFileDetails: Sendable {
    public let url: URL
    public var tags: AudioStandardTags
    public let specs: AudioTechnicalSpecs

    nonisolated public init(url: URL, tags: AudioStandardTags, specs: AudioTechnicalSpecs) {
        self.url = url
        self.tags = tags
        self.specs = specs
    }
}

nonisolated public struct AudioTagReader: Sendable {

    nonisolated public init() {}

    nonisolated public func readDetails(from url: URL) async -> AudioFileDetails {
        let fileSize: Int64 = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
        let ext = url.pathExtension.lowercased()

        var sampleRate: Double = 44100
        var channelCount: Int = 2
        var bitDepth: Int? = nil
        var duration: TimeInterval = 0

        // Attempt reading via AVAudioFile
        if let audioFile = try? AVAudioFile(forReading: url) {
            let fmt = audioFile.fileFormat
            sampleRate = fmt.sampleRate
            channelCount = Int(fmt.channelCount)
            if sampleRate > 0 {
                duration = Double(audioFile.length) / sampleRate
            }
            if fmt.commonFormat == .pcmFormatInt16 {
                bitDepth = 16
            } else if fmt.commonFormat == .pcmFormatInt32 {
                bitDepth = 32
            } else if fmt.commonFormat == .pcmFormatFloat32 {
                bitDepth = 24 // Common representation for hi-res
            }
        }

        let asset = AVURLAsset(url: url)
        if duration <= 0, let dur = try? await asset.load(.duration) {
            let seconds = CMTimeGetSeconds(dur)
            if seconds.isFinite && seconds > 0 {
                duration = seconds
            }
        }

        // Format name heuristics
        var formatName = ext.uppercased()
        switch ext {
        case "flac":
            formatName = "FLAC Lossless Audio"
        case "mp3":
            formatName = "MPEG-3 Audio (MP3)"
        case "m4a", "alac":
            formatName = "Apple Lossless / AAC (M4A)"
        case "wav", "wave":
            formatName = "Waveform Audio (WAV)"
        case "aiff", "aif":
            formatName = "AIFF Audio"
        case "dsf", "dff":
            formatName = "Direct Stream Digital (DSD)"
        default:
            break
        }

        // If FLAC, parse STREAMINFO for true bit depth & sample rate
        if ext == "flac", let flacHeader = readFLACStreamInfo(from: url) {
            sampleRate = flacHeader.sampleRate
            channelCount = flacHeader.channels
            bitDepth = flacHeader.bitDepth
        }

        var bitrate: Int? = nil
        if duration > 0 && fileSize > 0 {
            bitrate = Int(Double(fileSize * 8) / duration / 1000.0)
        }

        let specs = AudioTechnicalSpecs(
            formatName: formatName,
            sampleRate: sampleRate,
            bitDepth: bitDepth,
            channelCount: channelCount,
            duration: duration,
            fileSize: fileSize,
            bitrate: bitrate
        )

        let tags = await readTags(from: url, asset: asset, ext: ext)
        return AudioFileDetails(url: url, tags: tags, specs: specs)
    }

    nonisolated public func readTags(from url: URL, asset: AVURLAsset? = nil, ext: String? = nil) async -> AudioStandardTags {
        let fileExt = ext ?? url.pathExtension.lowercased()

        // If FLAC, custom Vorbis comment reader gives most accurate tags
        if fileExt == "flac", let vorbisTags = readFLACTags(from: url) {
            return vorbisTags
        }

        let asset = asset ?? AVURLAsset(url: url)
        var metadata: [AVMetadataItem] = []
        if let common = try? await asset.load(.commonMetadata) {
            metadata.append(contentsOf: common)
        }
        if let all = try? await asset.load(.metadata) {
            metadata.append(contentsOf: all)
        }
        if let formats = try? await asset.load(.availableMetadataFormats) {
            for fmt in formats {
                if let items = try? await asset.loadMetadata(for: fmt) {
                    metadata.append(contentsOf: items)
                }
            }
        }

        let parsed = FileNameHeuristicParser.parse(fileURL: url)

        let title = await metadataString(identifier: .commonIdentifierTitle, alternateKeys: ["title", "tit2", "©nam"], metadata: metadata) ?? parsed.title
        let artist = await metadataString(identifier: .commonIdentifierArtist, alternateKeys: ["artist", "tpe1", "©art"], metadata: metadata) ?? parsed.artist ?? "Unknown Artist"
        let album = await metadataString(identifier: .commonIdentifierAlbumName, alternateKeys: ["album", "talb", "©alb"], metadata: metadata) ?? parsed.album ?? ""
        let albumArtist = await metadataString(identifier: nil, alternateKeys: ["albumartist", "tpe2", "aart"], metadata: metadata)
        let genre = await metadataString(identifier: nil, alternateKeys: ["genre", "tcon", "©gen"], metadata: metadata)

        var trackNumber: Int? = parsed.trackNumber
        var totalTracks: Int? = nil
        if let trkStr = await metadataString(identifier: .id3MetadataTrackNumber, alternateKeys: ["tracknumber", "trck", "trkn"], metadata: metadata) {
            let parts = trkStr.components(separatedBy: "/")
            if let first = parts.first, let num = Int(first.trimmingCharacters(in: .whitespaces)) {
                trackNumber = num
            }
            if parts.count > 1, let total = Int(parts[1].trimmingCharacters(in: .whitespaces)) {
                totalTracks = total
            }
        }

        var discNumber: Int? = nil
        var totalDiscs: Int? = nil
        if let discStr = await metadataString(identifier: nil, alternateKeys: ["discnumber", "tpos", "disk"], metadata: metadata) {
            let parts = discStr.components(separatedBy: "/")
            if let first = parts.first, let num = Int(first.trimmingCharacters(in: .whitespaces)) {
                discNumber = num
            }
            if parts.count > 1, let total = Int(parts[1].trimmingCharacters(in: .whitespaces)) {
                totalDiscs = total
            }
        }

        var year: Int? = parsed.year
        if let dateStr = await metadataString(identifier: .id3MetadataYear, alternateKeys: ["date", "year", "tyer", "tdrc", "©day"], metadata: metadata) {
            let digits = dateStr.prefix(while: { $0.isNumber })
            if digits.count >= 4, let yr = Int(digits.prefix(4)) {
                year = yr
            }
        }

        let lyrics = await metadataString(identifier: nil, alternateKeys: ["lyrics", "uslt", "©lyr"], metadata: metadata)
        let artworkData = await metadataData(identifier: .commonIdentifierArtwork, metadata: metadata)

        return AudioStandardTags(
            title: title,
            artist: artist,
            album: album,
            albumArtist: albumArtist,
            trackNumber: trackNumber,
            totalTracks: totalTracks,
            discNumber: discNumber,
            totalDiscs: totalDiscs,
            year: year,
            genre: genre,
            artworkData: artworkData,
            lyrics: lyrics
        )
    }

    // MARK: - Private FLAC Direct Parsers

    private struct FLACStreamInfo {
        let sampleRate: Double
        let channels: Int
        let bitDepth: Int
    }

    private func readFLACStreamInfo(from url: URL) -> FLACStreamInfo? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        guard let magic = try? handle.read(upToCount: 4), magic.count == 4,
              magic[0] == 0x66, magic[1] == 0x4C, magic[2] == 0x61, magic[3] == 0x43 else {
            return nil
        }

        guard let blockHeader = try? handle.read(upToCount: 4), blockHeader.count == 4 else { return nil }
        let blockType = blockHeader[0] & 0x7F
        guard blockType == 0 else { return nil } // STREAMINFO must be block 0

        guard let streamInfo = try? handle.read(upToCount: 34), streamInfo.count >= 18 else { return nil }
        // Bytes 10-13 contain sample rate (20 bits), channels (3 bits), bits per sample (5 bits)
        let b10 = UInt32(streamInfo[10])
        let b11 = UInt32(streamInfo[11])
        let b12 = UInt32(streamInfo[12])
        let b13 = UInt32(streamInfo[13])

        let sampleRate = Double((b10 << 12) | (b11 << 4) | (b12 >> 4))
        let channels = Int(((b12 >> 1) & 0x07) + 1)
        let bitDepth = Int((((b12 & 0x01) << 4) | (b13 >> 4)) + 1)

        return FLACStreamInfo(sampleRate: sampleRate, channels: channels, bitDepth: bitDepth)
    }

    private func readFLACTags(from url: URL) -> AudioStandardTags? {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
        guard data.count > 4, data[0] == 0x66, data[1] == 0x4C, data[2] == 0x61, data[3] == 0x43 else {
            return nil
        }

        var offset = 4
        var comments: [String: String] = [:]
        var artworkData: Data? = nil

        while offset + 4 <= data.count {
            let headerByte = data[offset]
            let isLast = (headerByte & 0x80) != 0
            let blockType = headerByte & 0x7F
            let length = Int(data[offset + 1]) << 16 | Int(data[offset + 2]) << 8 | Int(data[offset + 3])
            offset += 4

            if offset + length > data.count { break }
            let block = data.subdata(in: offset..<offset + length)
            offset += length

            if blockType == 4 { // Vorbis comment
                var bOffset = 0
                if bOffset + 4 <= block.count {
                    let vendorLen = Int(block.subdata(in: bOffset..<bOffset + 4).withUnsafeBytes { $0.load(as: UInt32.self).littleEndian })
                    bOffset += 4 + vendorLen
                }
                if bOffset + 4 <= block.count {
                    let userCommentListLen = Int(block.subdata(in: bOffset..<bOffset + 4).withUnsafeBytes { $0.load(as: UInt32.self).littleEndian })
                    bOffset += 4

                    for _ in 0..<userCommentListLen {
                        guard bOffset + 4 <= block.count else { break }
                        let cLen = Int(block.subdata(in: bOffset..<bOffset + 4).withUnsafeBytes { $0.load(as: UInt32.self).littleEndian })
                        bOffset += 4
                        guard bOffset + cLen <= block.count else { break }
                        if let str = String(data: block.subdata(in: bOffset..<bOffset + cLen), encoding: .utf8) {
                            let parts = str.components(separatedBy: "=")
                            if parts.count >= 2 {
                                let key = parts[0].uppercased()
                                let val = parts.dropFirst().joined(separator: "=")
                                comments[key] = val
                            }
                        }
                        bOffset += cLen
                    }
                }
            } else if blockType == 6 && artworkData == nil { // PICTURE
                // Skip picture type (4), mime type len (4), mime type, desc len (4), desc, width (4), height (4), depth (4), colors (4)
                var pOffset = 4
                if pOffset + 4 <= block.count {
                    let mimeLen = Int(block.subdata(in: pOffset..<pOffset + 4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
                    pOffset += 4 + mimeLen
                }
                if pOffset + 4 <= block.count {
                    let descLen = Int(block.subdata(in: pOffset..<pOffset + 4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
                    pOffset += 4 + descLen
                }
                pOffset += 16 // width, height, depth, colors
                if pOffset + 4 <= block.count {
                    let dataLen = Int(block.subdata(in: pOffset..<pOffset + 4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
                    pOffset += 4
                    if pOffset + dataLen <= block.count {
                        artworkData = block.subdata(in: pOffset..<pOffset + dataLen)
                    }
                }
            }

            if isLast { break }
        }

        let parsed = FileNameHeuristicParser.parse(fileURL: url)
        let title = comments["TITLE"] ?? parsed.title
        let artist = comments["ARTIST"] ?? parsed.artist ?? "Unknown Artist"
        let album = comments["ALBUM"] ?? parsed.album ?? ""
        let albumArtist = comments["ALBUMARTIST"] ?? comments["ALBUM ARTIST"]
        let genre = comments["GENRE"]
        let trackNumber = comments["TRACKNUMBER"].flatMap { Int($0) } ?? parsed.trackNumber
        let totalTracks = comments["TRACKTOTAL"].flatMap { Int($0) } ?? comments["TOTALTRACKS"].flatMap { Int($0) }
        let discNumber = comments["DISCNUMBER"].flatMap { Int($0) }
        let totalDiscs = comments["DISCTOTAL"].flatMap { Int($0) } ?? comments["TOTALDISCS"].flatMap { Int($0) }
        let year = comments["DATE"].flatMap { Int($0.prefix(4)) } ?? parsed.year
        let lyrics = comments["LYRICS"] ?? comments["UNSYNCEDLYRICS"]

        return AudioStandardTags(
            title: title,
            artist: artist,
            album: album,
            albumArtist: albumArtist,
            trackNumber: trackNumber,
            totalTracks: totalTracks,
            discNumber: discNumber,
            totalDiscs: totalDiscs,
            year: year,
            genre: genre,
            artworkData: artworkData,
            lyrics: lyrics
        )
    }

    // MARK: - AVMetadata Helpers

    private func metadataString(
        identifier: AVMetadataIdentifier?,
        alternateKeys: [String],
        metadata: [AVMetadataItem]
    ) async -> String? {
        if let identifier {
            for item in metadata where item.identifier == identifier {
                if let str = try? await item.load(.stringValue), !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return str.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        for item in metadata {
            if let key = item.key as? String, alternateKeys.contains(key.lowercased()) {
                if let str = try? await item.load(.stringValue), !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return str.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        return nil
    }

    private func metadataData(
        identifier: AVMetadataIdentifier?,
        metadata: [AVMetadataItem]
    ) async -> Data? {
        if let identifier {
            for item in metadata where item.identifier == identifier {
                if let data = try? await item.load(.dataValue), !data.isEmpty {
                    return data
                }
            }
        }
        for item in metadata {
            if let key = item.key as? String, ["covr", "apic", "artwork", "cover"].contains(key.lowercased()) {
                if let data = try? await item.load(.dataValue), !data.isEmpty {
                    return data
                }
            }
        }
        return nil
    }
}

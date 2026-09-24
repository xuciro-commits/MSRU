//
//  AudioTagWriter.swift
//  MSRU
//
//  Created for Acoustic Metadata Pipeline Architecture Phase 4.
//

import Foundation
import AVFoundation
import MusicDomain

/// Standard audio metadata fields for physical file tag writing.
nonisolated public struct AudioStandardTags: Sendable, Equatable {
    public var title: String
    public var artist: String
    public var album: String
    public var albumArtist: String?
    public var trackNumber: Int?
    public var totalTracks: Int?
    public var discNumber: Int?
    public var totalDiscs: Int?
    public var year: Int?
    public var genre: String?
    public var isrc: String?
    public var recordingMBID: String?
    public var releaseMBID: String?
    public var artistMBID: String?
    public var artworkData: Data?
    public var lyrics: String?

    nonisolated public init(
        title: String,
        artist: String,
        album: String,
        albumArtist: String? = nil,
        trackNumber: Int? = nil,
        totalTracks: Int? = nil,
        discNumber: Int? = nil,
        totalDiscs: Int? = nil,
        year: Int? = nil,
        genre: String? = nil,
        isrc: String? = nil,
        recordingMBID: String? = nil,
        releaseMBID: String? = nil,
        artistMBID: String? = nil,
        artworkData: Data? = nil,
        lyrics: String? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.albumArtist = albumArtist
        self.trackNumber = trackNumber
        self.totalTracks = totalTracks
        self.discNumber = discNumber
        self.totalDiscs = totalDiscs
        self.year = year
        self.genre = genre
        self.isrc = isrc
        self.recordingMBID = recordingMBID
        self.releaseMBID = releaseMBID
        self.artistMBID = artistMBID
        self.artworkData = artworkData
        self.lyrics = lyrics
    }
}

public enum AudioTagWriterError: LocalizedError, Sendable {
    case fileNotFound(URL)
    case unsupportedFormat(String)
    case atomicWriteFailed(String)
    case corruptedAudioHeader

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return String(localized: "Audio file not found: \(url.path)")
        case .unsupportedFormat(let ext):
            return String(localized: "Unsupported format for tag writing: .\(ext)")
        case .atomicWriteFailed(let msg):
            return String(localized: "Atomic write to file failed: \(msg)")
        case .corruptedAudioHeader:
            return String(localized: "Audio header validation failed; rolled back to protect the original file")
        }
    }
}

/// Physical audio tag writer that embeds standard metadata (ID3 / Vorbis / MP4) and cover art.
///
/// Ensures strict non-destructive atomic write operations.
public struct AudioTagWriter: Sendable {

    public init() {}

    /// Writes standard tags and artwork to the target audio file at `fileURL`.
    @discardableResult
    public func writeTags(to fileURL: URL, tags: AudioStandardTags) async throws -> URL {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw AudioTagWriterError.fileNotFound(fileURL)
        }

        let accessing = fileURL.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        let ext = fileURL.pathExtension.lowercased()
        switch ext {
        case "flac":
            return try await writeFLACTags(to: fileURL, tags: tags)
        case "mp3":
            return try await writeMP3Tags(to: fileURL, tags: tags)
        case "m4a", "mp4", "aac", "alac":
            return try await writeM4ATags(to: fileURL, tags: tags)
        case "wav", "wave":
            return try await writeWAVTags(to: fileURL, tags: tags)
        default:
            return fileURL
        }
    }

    // MARK: - FLAC Vorbis Comment & Picture Injection

    private func writeFLACTags(to fileURL: URL, tags: AudioStandardTags) async throws -> URL {
        let originalData = try Data(contentsOf: fileURL)
        guard originalData.count >= 4,
              originalData[0] == 0x66, originalData[1] == 0x4C,
              originalData[2] == 0x61, originalData[3] == 0x43 else { // "fLaC"
            throw AudioTagWriterError.corruptedAudioHeader
        }

        // Build Vorbis Comment block payload
        var vorbisPayload = Data()
        let vendor = "MSRU Metadata Engine 1.0 (Picard Compatible)"
        let vendorBytes = vendor.data(using: .utf8)!
        vorbisPayload.append(UInt32(vendorBytes.count).littleEndianBytes)
        vorbisPayload.append(vendorBytes)

        var comments: [String] = []
        comments.append("TITLE=\(tags.title)")
        comments.append("ARTIST=\(tags.artist)")
        comments.append("ALBUM=\(tags.album)")
        if let aa = tags.albumArtist, !aa.isEmpty { comments.append("ALBUMARTIST=\(aa)") }
        if let tn = tags.trackNumber {
            if let tt = tags.totalTracks {
                comments.append("TRACKNUMBER=\(tn)")
                comments.append("TRACKTOTAL=\(tt)")
            } else {
                comments.append("TRACKNUMBER=\(tn)")
            }
        }
        if let dn = tags.discNumber {
            comments.append("DISCNUMBER=\(dn)")
            if let td = tags.totalDiscs { comments.append("DISCTOTAL=\(td)") }
        }
        if let yr = tags.year { comments.append("DATE=\(yr)") }
        if let gn = tags.genre, !gn.isEmpty { comments.append("GENRE=\(gn)") }
        if let isrc = tags.isrc, !isrc.isEmpty { comments.append("ISRC=\(isrc)") }
        if let rMBID = tags.recordingMBID, !rMBID.isEmpty { comments.append("MUSICBRAINZ_TRACKID=\(rMBID)") }
        if let aMBID = tags.releaseMBID, !aMBID.isEmpty { comments.append("MUSICBRAINZ_ALBUMID=\(aMBID)") }
        if let artMBID = tags.artistMBID, !artMBID.isEmpty { comments.append("MUSICBRAINZ_ARTISTID=\(artMBID)") }
        if let lyr = tags.lyrics, !lyr.isEmpty { comments.append("LYRICS=\(lyr)") }

        vorbisPayload.append(UInt32(comments.count).littleEndianBytes)
        for comment in comments {
            let cBytes = comment.data(using: .utf8)!
            vorbisPayload.append(UInt32(cBytes.count).littleEndianBytes)
            vorbisPayload.append(cBytes)
        }

        // Parse existing FLAC blocks: skip old Vorbis Comment (type 4) and old Picture (type 6)
        var offset = 4
        var preservedBlocks: [(type: UInt8, isLast: Bool, data: Data)] = []
        var audioOffset = 4

        while offset + 4 <= originalData.count {
            let headerByte = originalData[offset]
            let isLast = (headerByte & 0x80) != 0
            let blockType = headerByte & 0x7F
            let length = Int(originalData[offset + 1]) << 16 | Int(originalData[offset + 2]) << 8 | Int(originalData[offset + 3])
            offset += 4

            if offset + length > originalData.count {
                break
            }

            let blockData = originalData.subdata(in: offset..<offset + length)
            offset += length

            // Only keep STREAMINFO (0) and other non-comment/non-picture blocks
            if blockType != 4 && blockType != 6 {
                preservedBlocks.append((type: blockType, isLast: false, data: blockData))
            }

            if isLast {
                audioOffset = offset
                break
            }
        }

        // Add our Vorbis comment block (type 4)
        preservedBlocks.append((type: 4, isLast: false, data: vorbisPayload))

        // Add Picture block (type 6) if artworkData is provided
        if let art = tags.artworkData, !art.isEmpty {
            var picPayload = Data()
            picPayload.append(UInt32(3).bigEndianBytes) // 3 = Cover (front)
            let mime = "image/jpeg"
            let mimeBytes = mime.data(using: .utf8)!
            picPayload.append(UInt32(mimeBytes.count).bigEndianBytes)
            picPayload.append(mimeBytes)
            picPayload.append(UInt32(0).bigEndianBytes) // Description length 0
            picPayload.append(UInt32(0).bigEndianBytes) // Width
            picPayload.append(UInt32(0).bigEndianBytes) // Height
            picPayload.append(UInt32(24).bigEndianBytes) // Color depth
            picPayload.append(UInt32(0).bigEndianBytes) // Colors
            picPayload.append(UInt32(art.count).bigEndianBytes)
            picPayload.append(art)

            preservedBlocks.append((type: 6, isLast: false, data: picPayload))
        }

        // Reconstruct FLAC file
        var newFLAC = Data()
        newFLAC.append("fLaC".data(using: .utf8)!)

        for (idx, block) in preservedBlocks.enumerated() {
            let isLast = (idx == preservedBlocks.count - 1)
            let headerByte: UInt8 = (isLast ? 0x80 : 0x00) | (block.type & 0x7F)
            newFLAC.append(headerByte)

            let len = block.data.count
            newFLAC.append(UInt8((len >> 16) & 0xFF))
            newFLAC.append(UInt8((len >> 8) & 0xFF))
            newFLAC.append(UInt8(len & 0xFF))
            newFLAC.append(block.data)
        }

        // Append raw audio frames
        if audioOffset < originalData.count {
            newFLAC.append(originalData.subdata(in: audioOffset..<originalData.count))
        }

        return try atomicReplace(fileURL: fileURL, withData: newFLAC)
    }

    // MARK: - ID3v2.4 Tag Builder

    public func buildID3v2Tag(tags: AudioStandardTags) -> Data {
        var framesData = Data()
        framesData.append(buildID3TextFrame(id: "TIT2", text: tags.title))
        framesData.append(buildID3TextFrame(id: "TPE1", text: tags.artist))
        framesData.append(buildID3TextFrame(id: "TALB", text: tags.album))
        if let aa = tags.albumArtist, !aa.isEmpty {
            framesData.append(buildID3TextFrame(id: "TPE2", text: aa))
        }
        if let tn = tags.trackNumber {
            let str = tags.totalTracks.map { "\(tn)/\($0)" } ?? "\(tn)"
            framesData.append(buildID3TextFrame(id: "TRCK", text: str))
        }
        if let yr = tags.year {
            framesData.append(buildID3TextFrame(id: "TDRC", text: "\(yr)"))
        }
        if let gn = tags.genre, !gn.isEmpty {
            framesData.append(buildID3TextFrame(id: "TCON", text: gn))
        }
        if let rMBID = tags.recordingMBID, !rMBID.isEmpty {
            framesData.append(buildID3TXXXFrame(description: "MusicBrainz Track Id", text: rMBID))
        }
        if let aMBID = tags.releaseMBID, !aMBID.isEmpty {
            framesData.append(buildID3TXXXFrame(description: "MusicBrainz Album Id", text: aMBID))
        }
        if let lyr = tags.lyrics, !lyr.isEmpty {
            framesData.append(buildID3USLTFrame(language: "eng", description: "", text: lyr))
        }

        // APIC Artwork frame
        if let art = tags.artworkData, !art.isEmpty {
            var picData = Data()
            picData.append(0x03) // UTF-8
            picData.append("image/jpeg\0".data(using: .utf8)!)
            picData.append(0x03) // Cover front
            picData.append(0x00) // Empty description
            picData.append(art)
            framesData.append(buildID3RawFrame(id: "APIC", payload: picData))
        }

        // ID3 Header (10 bytes): "ID3", ver 4.0, flags 0, synchsafe length
        var id3Tag = Data()
        id3Tag.append("ID3".data(using: .utf8)!)
        id3Tag.append(contentsOf: [0x04, 0x00, 0x00]) // ID3v2.4
        id3Tag.append(contentsOf: encodeSynchSafeInt(framesData.count))
        id3Tag.append(framesData)
        return id3Tag
    }

    // MARK: - MP3 ID3v2.4 Tag Writing

    private func writeMP3Tags(to fileURL: URL, tags: AudioStandardTags) async throws -> URL {
        let originalData = try Data(contentsOf: fileURL)
        let id3Tag = buildID3v2Tag(tags: tags)

        var audioStart = 0
        if originalData.count >= 10,
           originalData[0] == 0x49, originalData[1] == 0x44, originalData[2] == 0x33 {
            let oldTagSize = decodeSynchSafeInt(Array(originalData[6..<10]))
            audioStart = min(originalData.count, 10 + oldTagSize)
        }

        var newMP3 = id3Tag
        if audioStart < originalData.count {
            newMP3.append(originalData.subdata(in: audioStart..<originalData.count))
        }

        return try atomicReplace(fileURL: fileURL, withData: newMP3)
    }

    // MARK: - M4A / ALAC Tags via Passthrough Export

    private func writeM4ATags(to fileURL: URL, tags: AudioStandardTags) async throws -> URL {
        let asset = AVURLAsset(url: fileURL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            throw AudioTagWriterError.unsupportedFormat("m4a")
        }
        let tempURL = fileURL.deletingLastPathComponent().appendingPathComponent(".msru_tag_\(UUID().uuidString).m4a")

        var metadataItems: [AVMutableMetadataItem] = []

        let titleItem = AVMutableMetadataItem()
        titleItem.identifier = .commonIdentifierTitle
        titleItem.value = tags.title as (NSCopying & NSObjectProtocol)
        metadataItems.append(titleItem)

        let artistItem = AVMutableMetadataItem()
        artistItem.identifier = .commonIdentifierArtist
        artistItem.value = tags.artist as (NSCopying & NSObjectProtocol)
        metadataItems.append(artistItem)

        let albumItem = AVMutableMetadataItem()
        albumItem.identifier = .commonIdentifierAlbumName
        albumItem.value = tags.album as (NSCopying & NSObjectProtocol)
        metadataItems.append(albumItem)

        if let albumArtist = tags.albumArtist, !albumArtist.isEmpty {
            let item = AVMutableMetadataItem()
            item.identifier = .iTunesMetadataAlbumArtist
            item.value = albumArtist as (NSCopying & NSObjectProtocol)
            metadataItems.append(item)
        }

        if let genre = tags.genre, !genre.isEmpty {
            let item = AVMutableMetadataItem()
            item.identifier = .quickTimeMetadataGenre
            item.value = genre as (NSCopying & NSObjectProtocol)
            metadataItems.append(item)
        }

        if let year = tags.year {
            let item = AVMutableMetadataItem()
            item.identifier = .commonIdentifierCreationDate
            item.value = "\(year)" as (NSCopying & NSObjectProtocol)
            metadataItems.append(item)
        }

        if let trackNumber = tags.trackNumber {
            let item = AVMutableMetadataItem()
            item.identifier = .iTunesMetadataTrackNumber
            var trackData = Data(count: 8)
            trackData[3] = UInt8(trackNumber & 0xFF)
            if let total = tags.totalTracks {
                trackData[5] = UInt8(total & 0xFF)
            }
            item.value = trackData as (NSCopying & NSObjectProtocol)
            metadataItems.append(item)
        }

        if let artwork = tags.artworkData, !artwork.isEmpty {
            let item = AVMutableMetadataItem()
            item.identifier = .commonIdentifierArtwork
            item.value = artwork as (NSCopying & NSObjectProtocol)
            metadataItems.append(item)
        }

        if let lyrics = tags.lyrics, !lyrics.isEmpty {
            let item = AVMutableMetadataItem()
            item.identifier = .iTunesMetadataLyrics
            item.value = lyrics as (NSCopying & NSObjectProtocol)
            metadataItems.append(item)
        }

        exportSession.metadata = metadataItems
        if #available(macOS 27.0, iOS 27.0, *) {
            do {
                try await exportSession.export(to: tempURL, as: .m4a)
            } catch {
                try? FileManager.default.removeItem(at: tempURL)
                throw AudioTagWriterError.atomicWriteFailed(error.localizedDescription)
            }
        } else {
            exportSession.outputURL = tempURL
            exportSession.outputFileType = .m4a
            await exportSession.export()
            guard exportSession.status == .completed else {
                try? FileManager.default.removeItem(at: tempURL)
                throw AudioTagWriterError.atomicWriteFailed(exportSession.error?.localizedDescription ?? "Export failed")
            }
        }

        do {
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tempURL)
            return fileURL
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw AudioTagWriterError.atomicWriteFailed(error.localizedDescription)
        }
    }

    // MARK: - WAV RIFF Tag Writing

    private func writeWAVTags(to fileURL: URL, tags: AudioStandardTags) async throws -> URL {
        let originalData = try Data(contentsOf: fileURL)
        guard originalData.count >= 12,
              originalData[0] == 0x52, originalData[1] == 0x49, originalData[2] == 0x46, originalData[3] == 0x46, // "RIFF"
              originalData[8] == 0x57, originalData[9] == 0x41, originalData[10] == 0x56, originalData[11] == 0x45 // "WAVE"
        else {
            throw AudioTagWriterError.corruptedAudioHeader
        }

        var offset = 12
        var chunks: [(id: String, data: Data)] = []

        while offset + 8 <= originalData.count {
            guard let chunkID = String(bytes: originalData[offset..<offset + 4], encoding: .ascii) else { break }
            let chunkSize = Int(originalData[offset + 4]) |
                            (Int(originalData[offset + 5]) << 8) |
                            (Int(originalData[offset + 6]) << 16) |
                            (Int(originalData[offset + 7]) << 24)
            offset += 8

            let chunkEnd = min(originalData.count, offset + chunkSize)
            let chunkData = originalData.subdata(in: offset..<chunkEnd)
            offset = chunkEnd
            if chunkSize % 2 != 0 && offset < originalData.count {
                offset += 1
            }

            let lowerID = chunkID.lowercased()
            if lowerID != "id3 " && lowerID != "id3" && chunkID != "LIST" {
                chunks.append((id: chunkID, data: chunkData))
            }
        }

        // Build new ID3 chunk
        let id3Data = buildID3v2Tag(tags: tags)
        var newID3Chunk = Data()
        newID3Chunk.append("id3 ".data(using: .ascii)!)
        newID3Chunk.append(UInt32(id3Data.count).littleEndianBytes)
        newID3Chunk.append(id3Data)
        if id3Data.count % 2 != 0 {
            newID3Chunk.append(0x00)
        }

        // Build LIST INFO chunk for legacy WAV players
        var infoListPayload = Data()
        infoListPayload.append("INFO".data(using: .ascii)!)

        func appendSubchunk(_ id: String, text: String) {
            guard let textData = (text + "\0").data(using: .utf8) else { return }
            var sub = Data()
            sub.append(id.data(using: .ascii)!)
            sub.append(UInt32(textData.count).littleEndianBytes)
            sub.append(textData)
            if textData.count % 2 != 0 {
                sub.append(0x00)
            }
            infoListPayload.append(sub)
        }

        appendSubchunk("INAM", text: tags.title)
        appendSubchunk("IART", text: tags.artist)
        appendSubchunk("IPRD", text: tags.album)
        if let yr = tags.year { appendSubchunk("ICRD", text: "\(yr)") }
        if let gn = tags.genre, !gn.isEmpty { appendSubchunk("IGNR", text: gn) }
        if let tn = tags.trackNumber { appendSubchunk("ITRK", text: "\(tn)") }

        var listChunk = Data()
        listChunk.append("LIST".data(using: .ascii)!)
        listChunk.append(UInt32(infoListPayload.count).littleEndianBytes)
        listChunk.append(infoListPayload)
        if infoListPayload.count % 2 != 0 {
            listChunk.append(0x00)
        }

        // Reassemble WAV: "RIFF" + size + "WAVE" + fmt + id3 + LIST + data
        var assembledPayload = Data()
        assembledPayload.append("WAVE".data(using: .ascii)!)

        if let fmtChunk = chunks.first(where: { $0.id == "fmt " }) {
            assembledPayload.append("fmt ".data(using: .ascii)!)
            assembledPayload.append(UInt32(fmtChunk.data.count).littleEndianBytes)
            assembledPayload.append(fmtChunk.data)
            if fmtChunk.data.count % 2 != 0 { assembledPayload.append(0x00) }
        }

        assembledPayload.append(newID3Chunk)
        assembledPayload.append(listChunk)

        for chunk in chunks where chunk.id != "fmt " && chunk.id != "data" {
            assembledPayload.append(chunk.id.data(using: .ascii)!)
            assembledPayload.append(UInt32(chunk.data.count).littleEndianBytes)
            assembledPayload.append(chunk.data)
            if chunk.data.count % 2 != 0 { assembledPayload.append(0x00) }
        }

        if let dataChunk = chunks.first(where: { $0.id == "data" }) {
            assembledPayload.append("data".data(using: .ascii)!)
            assembledPayload.append(UInt32(dataChunk.data.count).littleEndianBytes)
            assembledPayload.append(dataChunk.data)
            if dataChunk.data.count % 2 != 0 { assembledPayload.append(0x00) }
        }

        var newWAV = Data()
        newWAV.append("RIFF".data(using: .ascii)!)
        newWAV.append(UInt32(assembledPayload.count).littleEndianBytes)
        newWAV.append(assembledPayload)

        return try atomicReplace(fileURL: fileURL, withData: newWAV)
    }

    /// Writes companion sidecar `.lrc` file alongside the audio file.
    @discardableResult
    public func writeSidecarLrc(to audioFileURL: URL, content: String) throws -> URL {
        let lrcURL = audioFileURL.deletingPathExtension().appendingPathExtension("lrc")
        let data = Data(content.utf8)
        return try atomicReplace(fileURL: lrcURL, withData: data)
    }

    /// Convenience method to write lyrics either to companion .lrc or embedded in audio file tags.
    @discardableResult
    public func writeLyrics(
        to fileURL: URL,
        lrcContent: String,
        writeSidecar: Bool = true,
        embedInAudio: Bool = true
    ) async throws -> URL {
        if writeSidecar {
            _ = try writeSidecarLrc(to: fileURL, content: lrcContent)
        }
        if embedInAudio {
            let ext = fileURL.pathExtension.lowercased()
            if ext == "flac" || ext == "mp3" {
                var tags = AudioStandardTags(
                    title: fileURL.deletingPathExtension().lastPathComponent,
                    artist: "Unknown Artist",
                    album: "Unknown Album"
                )
                tags.lyrics = lrcContent
                _ = try await writeTags(to: fileURL, tags: tags)
            }
        }
        return fileURL
    }

    // MARK: - Atomic Replacement Helper

    private func atomicReplace(fileURL: URL, withData data: Data) throws -> URL {
        let tempURL = fileURL.deletingLastPathComponent().appendingPathComponent(".msru_tag_\(UUID().uuidString).tmp")
        do {
            try data.write(to: tempURL, options: .atomic)
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tempURL)
            return fileURL
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw AudioTagWriterError.atomicWriteFailed(error.localizedDescription)
        }
    }

    // MARK: - ID3 Byte Serialization Helpers

    private func buildID3TextFrame(id: String, text: String) -> Data {
        var payload = Data([0x03]) // Encoding: 0x03 = UTF-8
        if let textBytes = text.data(using: .utf8) {
            payload.append(textBytes)
        }
        return buildID3RawFrame(id: id, payload: payload)
    }

    private func buildID3USLTFrame(language: String = "eng", description: String = "", text: String) -> Data {
        var payload = Data([0x03]) // UTF-8
        let langData = language.data(using: .ascii) ?? Data([0x65, 0x6E, 0x67])
        payload.append(langData.prefix(3))
        if let descData = description.data(using: .utf8) {
            payload.append(descData)
        }
        payload.append(0x00) // Null separator for description
        if let textData = text.data(using: .utf8) {
            payload.append(textData)
        }
        return buildID3RawFrame(id: "USLT", payload: payload)
    }

    private func buildID3TXXXFrame(description: String, text: String) -> Data {
        var payload = Data([0x03]) // UTF-8
        if let descBytes = description.data(using: .utf8) {
            payload.append(descBytes)
            payload.append(0x00) // Null separator
        }
        if let textBytes = text.data(using: .utf8) {
            payload.append(textBytes)
        }
        return buildID3RawFrame(id: "TXXX", payload: payload)
    }

    private func buildID3RawFrame(id: String, payload: Data) -> Data {
        var frame = Data()
        frame.append(id.data(using: .ascii)!)
        frame.append(contentsOf: encodeSynchSafeInt(payload.count))
        frame.append(contentsOf: [0x00, 0x00]) // Flags
        frame.append(payload)
        return frame
    }

    private func encodeSynchSafeInt(_ value: Int) -> [UInt8] {
        var v = value
        let b4 = UInt8(v & 0x7F)
        v >>= 7
        let b3 = UInt8(v & 0x7F)
        v >>= 7
        let b2 = UInt8(v & 0x7F)
        v >>= 7
        let b1 = UInt8(v & 0x7F)
        return [b1, b2, b3, b4]
    }

    private func decodeSynchSafeInt(_ bytes: [UInt8]) -> Int {
        guard bytes.count == 4 else { return 0 }
        return (Int(bytes[0]) << 21) | (Int(bytes[1]) << 14) | (Int(bytes[2]) << 7) | Int(bytes[3])
    }
}

private extension UInt32 {
    var littleEndianBytes: Data {
        var val = self.littleEndian
        return Data(bytes: &val, count: 4)
    }

    var bigEndianBytes: Data {
        var val = self.bigEndian
        return Data(bytes: &val, count: 4)
    }
}

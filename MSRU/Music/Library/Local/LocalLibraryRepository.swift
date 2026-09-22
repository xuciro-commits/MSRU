import Foundation
import AVFoundation

/// Local media I/O boundary. UI state and selection remain in the store/scene.
protocol LocalLibraryRepository: Sendable {
    func loadTracks() async throws -> [LocalTrack]
    func importTrack(from url: URL) async throws -> LocalTrack?
    func importTracks(from urls: [URL]) async throws -> [LocalTrack]
    func saveTrackInPlace(_ track: LocalTrack) async throws
    func saveTracksInPlace(_ tracks: [LocalTrack]) async throws
    func batchUpsertTracks(_ tracks: [LocalTrack]) async throws
    func deleteTracks(withIDs ids: Set<String>, deletePhysicalFiles: Bool) async throws
    func readTrack(from url: URL) async throws -> LocalTrack
}

extension LocalLibraryRepository {
    func saveTrackInPlace(_ track: LocalTrack) async throws {
        try await saveTracksInPlace([track])
    }
    func saveTracksInPlace(_ tracks: [LocalTrack]) async throws {}
    func batchUpsertTracks(_ tracks: [LocalTrack]) async throws {
        try await saveTracksInPlace(tracks)
    }
    func importTracks(from urls: [URL]) async throws -> [LocalTrack] {
        var imported: [LocalTrack] = []
        for url in urls {
            if let track = try await importTrack(from: url) {
                imported.append(track)
            }
        }
        return imported
    }
    func deleteTracks(withIDs ids: Set<String>, deletePhysicalFiles: Bool) async throws {}
    func readTrack(from url: URL) async throws -> LocalTrack {
        try await FileLocalLibraryRepository.readTrack(from: url)
    }
}

nonisolated private struct PersistedTrackRecord: Codable {
    let fileURL: URL
    let bookmarkData: Data?
    let title: String
    let artist: String
    let album: String?
    let duration: TimeInterval
    let artworkRelativePath: String?
    let artworkData: Data?
    let trackNumber: Int?
    let year: Int?

    init(
        fileURL: URL,
        bookmarkData: Data?,
        title: String,
        artist: String,
        album: String?,
        duration: TimeInterval,
        artworkRelativePath: String?,
        artworkData: Data? = nil,
        trackNumber: Int? = nil,
        year: Int? = nil
    ) {
        self.fileURL = fileURL
        self.bookmarkData = bookmarkData
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.artworkRelativePath = artworkRelativePath
        self.artworkData = artworkData
        self.trackNumber = trackNumber
        self.year = year
    }

    func toLocalTrack() -> LocalTrack {
        return LocalTrack(
            fileURL: fileURL,
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            artworkReference: artworkRelativePath,
            artworkData: nil,
            trackNumber: trackNumber,
            year: year
        )
    }
}

actor FileLocalLibraryRepository: LocalLibraryRepository {
    private let directory: URL?

    init(directory: URL? = nil) {
        self.directory = directory
    }

    func loadTracks() async throws -> [LocalTrack] {
        let directory = try mediaDirectory()

        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        let supportedURLs = urls.filter { isSupported($0) }.sorted {
            $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending
        }

        var loadedTracks: [LocalTrack] = []

        for url in supportedURLs {
            do {
                let track = try await readTrack(from: url)
                loadedTracks.append(track)
            } catch {
                print("Local metadata failed:", url.lastPathComponent, error.localizedDescription)
            }
        }

        // Also merge in-place referenced external tracks with O(M+N) complexity
        let externalTracks = loadExternalTracks()
        var existingPaths = Set(loadedTracks.map { $0.fileURL.standardizedFileURL.path })
        for ext in externalTracks {
            let path = ext.fileURL.standardizedFileURL.path
            if existingPaths.insert(path).inserted {
                loadedTracks.append(ext)
            }
        }

        return loadedTracks
    }

    func importTrack(from url: URL) async throws -> LocalTrack? {
        let list = try await importTracks(from: [url])
        return list.first
    }

    func importTracks(from urls: [URL]) async throws -> [LocalTrack] {
        let supported = urls.filter { isSupported($0) }
        guard !supported.isEmpty else { return [] }

        var readList: [LocalTrack] = []
        for url in supported {
            if directory != nil {
                do {
                    let track = try await readTrack(from: copyFile(url))
                    readList.append(track)
                } catch {
                    print("Batch copy failed:", url.lastPathComponent, error.localizedDescription)
                }
            } else {
                let hasSecurityAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if hasSecurityAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                do {
                    let track = try await readTrack(from: url)
                    readList.append(track)
                } catch {
                    print("Batch read failed:", url.lastPathComponent, error.localizedDescription)
                }
            }
        }

        try await saveTracksInPlace(readList)
        return readList
    }

    func saveTracksInPlace(_ tracks: [LocalTrack]) async throws {
        guard !tracks.isEmpty else { return }
        let manifestURL = try externalManifestURL()
        var existingRecords: [PersistedTrackRecord] = []
        if let data = try? Data(contentsOf: manifestURL),
           let decoded = try? JSONDecoder().decode([PersistedTrackRecord].self, from: data) {
            existingRecords = decoded
        }

        let bookmarkOptions = SecurityScopePolicy.bookmarkCreationOptions

        var recordMap: [String: Int] = [:]
        for (idx, rec) in existingRecords.enumerated() {
            recordMap[rec.fileURL.standardizedFileURL.path] = idx
        }

        for track in tracks {
            let key = track.fileURL.standardizedFileURL.path
            let bookmark = try? track.fileURL.bookmarkData(options: bookmarkOptions, includingResourceValuesForKeys: nil, relativeTo: nil)

            // Decouple artwork data: store on disk in LocalArtworkStorage, do not serialize into JSON
            var relPath: String? = track.artworkReference
            if relPath == nil, let art = track.artworkData {
                relPath = LocalArtworkStorage.shared.storeArtwork(art)
            } else if relPath == nil, let existingIdx = recordMap[key] {
                relPath = existingRecords[existingIdx].artworkRelativePath
            }

            let newRecord = PersistedTrackRecord(
                fileURL: track.fileURL,
                bookmarkData: bookmark,
                title: track.title,
                artist: track.artist,
                album: track.album,
                duration: track.duration,
                artworkRelativePath: relPath,
                artworkData: nil,
                trackNumber: track.trackNumber,
                year: track.year
            )
            if let existingIdx = recordMap[key] {
                existingRecords[existingIdx] = newRecord
            } else {
                recordMap[key] = existingRecords.count
                existingRecords.append(newRecord)
            }
        }

        let encoded = try JSONEncoder().encode(existingRecords)
        try encoded.write(to: manifestURL, options: .atomic)
    }

    func saveTrackInPlace(_ track: LocalTrack) async throws {
        try await saveTracksInPlace([track])
    }

    func deleteTracks(withIDs ids: Set<String>, deletePhysicalFiles: Bool) async throws {
        let manifestURL = try externalManifestURL()
        var existingRecords: [PersistedTrackRecord] = []
        if let data = try? Data(contentsOf: manifestURL),
           let decoded = try? JSONDecoder().decode([PersistedTrackRecord].self, from: data) {
            existingRecords = decoded
        }

        let tracksToDelete = existingRecords.filter {
            ids.contains($0.fileURL.absoluteString) ||
            ids.contains($0.fileURL.standardizedFileURL.path) ||
            ids.contains($0.fileURL.path)
        }

        existingRecords.removeAll {
            ids.contains($0.fileURL.absoluteString) ||
            ids.contains($0.fileURL.standardizedFileURL.path) ||
            ids.contains($0.fileURL.path)
        }

        let encoded = try JSONEncoder().encode(existingRecords)
        try encoded.write(to: manifestURL, options: .atomic)

        if deletePhysicalFiles {
            var foldersToCheck: Set<URL> = []
            for record in tracksToDelete {
                let hasAccess = record.fileURL.startAccessingSecurityScopedResource()
                defer { if hasAccess { record.fileURL.stopAccessingSecurityScopedResource() } }

                let parent = record.fileURL.deletingLastPathComponent()
                foldersToCheck.insert(parent)

                do {
                    try FileManager.default.trashItem(at: record.fileURL, resultingItemURL: nil)
                } catch {
                    try? FileManager.default.removeItem(at: record.fileURL)
                }
            }

            // Cascade clean orphan companion covers and empty folders if no audio files remain
            for folder in foldersToCheck {
                let items = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
                let audioItems = items.filter { LocalAudioFormatSupport.supports($0) }
                if audioItems.isEmpty {
                    // No audio tracks left in this album folder. Clean companion artwork
                    let companionImages = items.filter { item in
                        let ext = item.pathExtension.lowercased()
                        return ["jpg", "jpeg", "png", "webp"].contains(ext)
                    }
                    for img in companionImages {
                        do {
                            try FileManager.default.trashItem(at: img, resultingItemURL: nil)
                        } catch {
                            try? FileManager.default.removeItem(at: img)
                        }
                    }

                    // Re-check if directory is now empty of non-hidden files
                    let remaining = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [])) ?? []
                    let nonHiddenRemaining = remaining.filter { !$0.lastPathComponent.hasPrefix(".") }
                    if nonHiddenRemaining.isEmpty {
                        do {
                            try FileManager.default.trashItem(at: folder, resultingItemURL: nil)
                        } catch {
                            try? FileManager.default.removeItem(at: folder)
                        }
                    }
                }
            }
        }
    }

    private func externalManifestURL() throws -> URL {
        try mediaDirectory().appendingPathComponent("external_tracks.json")
    }

    private func loadExternalTracks() -> [LocalTrack] {
        guard let manifestURL = try? externalManifestURL(),
              let data = try? Data(contentsOf: manifestURL),
              let records = try? JSONDecoder().decode([PersistedTrackRecord].self, from: data) else {
            return []
        }

        var tracks: [LocalTrack] = []
        for record in records {
            tracks.append(LocalTrack(
                fileURL: record.fileURL,
                title: record.title,
                artist: record.artist,
                album: record.album,
                duration: record.duration,
                artworkReference: record.artworkRelativePath,
                artworkData: nil,
                trackNumber: record.trackNumber,
                year: record.year
            ))
        }
        return tracks
    }

    // MARK: - Import File

    private func copyFile(
        _ sourceURL: URL
    ) throws -> URL {

        let hasSecurityAccess =
            sourceURL
                .startAccessingSecurityScopedResource()


        defer {

            if hasSecurityAccess {

                sourceURL
                    .stopAccessingSecurityScopedResource()
            }
        }


        let directory =
            try mediaDirectory()


        let destinationURL =
            uniqueDestinationURL(
                for:
                    sourceURL,
                in:
                    directory
            )


        try FileManager
            .default
            .copyItem(
                at:
                    sourceURL,
                to:
                    destinationURL
            )


        print(
            "Local Import ✓",
            destinationURL
                .lastPathComponent
        )


        return destinationURL
    }



    // MARK: - Metadata

    func readTrack(from url: URL) async throws -> LocalTrack {
        try await Self.readTrack(from: url)
    }

    static func readTrack(
        from url:
            URL
    ) async throws -> LocalTrack {
        let url = url.resolvingSymlinksInPath().standardizedFileURL

        let asset =
            AVURLAsset(
                url:
                    url
            )


        // Fast path for DSD DSF files: bypass AVFoundation to prevent CoreAudio FFR errors
        if url.pathExtension.lowercased() == "dsf", let dsfMeta = DSFHeaderReader.readMetadata(from: url) {
            let parsed = FileNameHeuristicParser.parse(fileURL: url)
            let rule = PathHeuristicRuleStore.shared.match(fileURL: url)
            let title = dsfMeta.title ?? parsed.title
            let artist = dsfMeta.artist ?? rule?.targetArtist ?? parsed.artist ?? "Unknown Artist"
            let album = dsfMeta.album ?? rule?.targetAlbum ?? parsed.album
            let artworkData = dsfMeta.artworkData ?? LocalArtworkExtractor.extractFromDirectory(folderURL: url.deletingLastPathComponent())
            let trackNumber = dsfMeta.trackNumber ?? parsed.trackNumber
            let year = dsfMeta.year ?? parsed.year

            return LocalTrack(
                fileURL: url,
                title: title,
                artist: artist,
                album: album,
                duration: dsfMeta.duration,
                artworkData: artworkData,
                trackNumber: trackNumber,
                year: year
            )
        }

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

        // MARK: Title

        let parsed = FileNameHeuristicParser.parse(fileURL: url)
        let rule = PathHeuristicRuleStore.shared.match(fileURL: url)

        let rawTitle =
            await metadataString(
                identifier: .commonIdentifierTitle,
                alternateKeys: ["title"],
                metadata: metadata
            )
        let title = (rawTitle != nil && !rawTitle!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            ? rawTitle!
            : parsed.title


        let rawArtist =
            await metadataString(
                identifier: .commonIdentifierArtist,
                alternateKeys: ["artist", "albumartist", "composer"],
                metadata: metadata
            )
        let artist: String
        if let rawArtist, !rawArtist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, rawArtist != "Unknown Artist" {
            artist = rawArtist
        } else {
            artist = rule?.targetArtist ?? parsed.artist ?? "Unknown Artist"
        }

        // Clean redundant artist prefix from title if present (e.g. "李克勤-一生不变" -> "一生不变")
        var finalTitle = title
        if finalTitle.lowercased().hasPrefix(artist.lowercased()) {
            let stripped = finalTitle.dropFirst(artist.count).trimmingCharacters(in: CharacterSet(charactersIn: " -–—_"))
            if !stripped.isEmpty {
                finalTitle = stripped
            }
        }

        // MARK: Album

        let rawAlbum =
            await metadataString(
                identifier: .commonIdentifierAlbumName,
                alternateKeys: ["album"],
                metadata: metadata
            )
        var finalAlbum = (rawAlbum != nil && !rawAlbum!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            ? rawAlbum
            : (rule?.targetAlbum ?? parsed.album)

        // Safety gate: never allow album == artist
        if let alb = finalAlbum, alb.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            finalAlbum = nil
        }


        // MARK: Artwork

        var artworkData =
            await metadataData(
                identifier: .commonIdentifierArtwork,
                metadata: metadata
            )
        if artworkData == nil {
            artworkData = LocalArtworkExtractor.extractFromDirectory(folderURL: url.deletingLastPathComponent())
        }

        // MARK: TrackNumber & Year
        var trackNumber: Int? = parsed.trackNumber
        if let rawTrk = await metadataString(identifier: .id3MetadataTrackNumber, alternateKeys: ["tracknumber", "trck"], metadata: metadata) {
            let digits = rawTrk.prefix(while: { $0.isNumber })
            if let num = Int(digits) {
                trackNumber = num
            }
        }

        var year: Int? = parsed.year
        if let rawDate = await metadataString(identifier: .id3MetadataYear, alternateKeys: ["date", "year", "tyer", "tdrc"], metadata: metadata) {
            let digits = rawDate.prefix(while: { $0.isNumber })
            if digits.count >= 4, let yr = Int(digits.prefix(4)) {
                year = yr
            }
        }

        // MARK: Duration

        let duration:
            TimeInterval


        do {

            let durationValue =
                try await asset.load(
                    .duration
                )


            let seconds =
                durationValue.seconds


            duration =
                seconds.isFinite
                && seconds > 0
                ? seconds
                : 0

        } catch {

            duration = 0


            print(
                """
                Local Metadata △
                \(url.lastPathComponent)
                duration unavailable:
                \(error.localizedDescription)
                """
            )
        }


        // MARK: Diagnostics

        print(
            """
            Local Metadata ✓
            file: \(url.lastPathComponent)
            format: \(url.pathExtension.lowercased())
            title: \(finalTitle)
            artist: \(artist)
            album: \(finalAlbum ?? "—")
            duration: \(duration)
            artwork: \(artworkData != nil)
            """
        )


        return LocalTrack(
            fileURL: url,
            title: finalTitle,
            artist: artist,
            album: finalAlbum,
            duration: duration,
            artworkData: artworkData,
            trackNumber: trackNumber,
            year: year
        )
    }

    private static func metadataString(
        identifier: AVMetadataIdentifier,
        alternateKeys: [String] = [],
        metadata: [AVMetadataItem]
    ) async -> String? {
        // 1. Exact identifier match
        let items = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: identifier)
        for item in items {
            if let val = try? await item.load(.stringValue), !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return val.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // 2. Alternate key / Vorbis comment match (e.g. "vorb/TITLE", "vorb/ALBUM", "TITLE", "ALBUM")
        let lowerAlts = alternateKeys.map { $0.lowercased() }
        for item in metadata {
            let keyStr = (item.key as? String)?.lowercased() ?? ""
            let idStr = item.identifier?.rawValue.lowercased() ?? ""
            for alt in lowerAlts {
                if keyStr == alt || idStr == alt || idStr.hasSuffix("/" + alt) {
                    if let val = try? await item.load(.stringValue), !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        return val.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
        }

        return nil
    }

    private static func metadataData(
        identifier: AVMetadataIdentifier,
        metadata: [AVMetadataItem]
    ) async -> Data? {
        // 1. Exact commonIdentifierArtwork match
        let items = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: identifier)
        for item in items {
            if let data = try? await item.load(.dataValue), LocalArtworkExtractor.isValidImageData(data) {
                return data
            }
        }

        // 2. Vorbis picture block or attached picture metadata
        for item in metadata {
            let idStr = item.identifier?.rawValue.lowercased() ?? ""
            let keyStr = (item.key as? String)?.lowercased() ?? ""
            if idStr.contains("picture") || keyStr.contains("picture") || idStr.contains("artwork") || keyStr.contains("artwork") {
                if let data = try? await item.load(.dataValue), LocalArtworkExtractor.isValidImageData(data) {
                    return data
                }
            }
        }

        // 3. Fallback: check any item with valid image data
        for item in metadata {
            if let data = try? await item.load(.dataValue), LocalArtworkExtractor.isValidImageData(data) {
                return data
            }
        }

        return nil
    }


    // MARK: - Storage

    private func mediaDirectory() throws -> URL {
        let resolved: URL
        if let directory {
            resolved = directory
        } else {
            guard let support = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask).first else {
                throw LocalLibraryError.applicationSupportUnavailable
            }
            resolved = support.appendingPathComponent("MSRU/LocalMedia", isDirectory: true)
        }
        try FileManager.default.createDirectory(at: resolved, withIntermediateDirectories: true)
        return resolved
    }

    private func uniqueDestinationURL(
        for sourceURL: URL,
        in directory: URL
    ) -> URL {

        let fileManager =
            FileManager.default


        let original =
            directory
                .appendingPathComponent(
                    sourceURL
                        .lastPathComponent
                )


        guard
            fileManager
                .fileExists(
                    atPath:
                        original.path
                )
        else {
            return original
        }


        let baseName =
            sourceURL
                .deletingPathExtension()
                .lastPathComponent


        let fileExtension =
            sourceURL
                .pathExtension


        let suffix =
            UUID()
                .uuidString
                .prefix(8)


        let fileName =
            fileExtension.isEmpty
            ? "\(baseName)-\(suffix)"
            : "\(baseName)-\(suffix).\(fileExtension)"


        return directory
            .appendingPathComponent(
                fileName
            )
    }


    private func isSupported(
        _ url:
            URL
    ) -> Bool {
        LocalAudioFormatSupport
            .supports(
                url
            )
    }
}


// MARK: - Errors

private enum LocalLibraryError:
    LocalizedError {

    case applicationSupportUnavailable


    var errorDescription:
        String? {

        switch self {

        case .applicationSupportUnavailable:

            "Could not access the application support directory."
        }
    }
}

import Foundation
import AVFoundation

/// Local media I/O boundary. UI state and selection remain in the store/scene.
@MainActor
protocol LocalLibraryRepository {
    func loadTracks() async throws -> [LocalTrack]
    func importTrack(from url: URL) async throws -> LocalTrack?
    func saveTrackInPlace(_ track: LocalTrack) async throws
    func deleteTracks(withIDs ids: Set<String>, deletePhysicalFiles: Bool) async throws
    func readTrack(from url: URL) async throws -> LocalTrack
}

extension LocalLibraryRepository {
    func saveTrackInPlace(_ track: LocalTrack) async throws {}
    func deleteTracks(withIDs ids: Set<String>, deletePhysicalFiles: Bool) async throws {}
    func readTrack(from url: URL) async throws -> LocalTrack {
        try await FileLocalLibraryRepository.readTrack(from: url)
    }
}

private struct PersistedTrackRecord: Codable {
    let fileURL: URL
    let bookmarkData: Data?
    let title: String
    let artist: String
    let album: String?
    let duration: TimeInterval
    let artworkData: Data?

    func toLocalTrack() -> LocalTrack {
        LocalTrack(
            fileURL: fileURL,
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            artworkData: artworkData
        )
    }
}

@MainActor
final class FileLocalLibraryRepository: LocalLibraryRepository {
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

        // Also merge in-place referenced external tracks
        let externalTracks = loadExternalTracks()
        for ext in externalTracks {
            if !loadedTracks.contains(where: { $0.fileURL.standardizedFileURL == ext.fileURL.standardizedFileURL }) {
                loadedTracks.append(ext)
            }
        }

        return loadedTracks
    }

    func importTrack(from url: URL) async throws -> LocalTrack? {
        guard isSupported(url) else { return nil }

        if directory != nil {
            // Injected test directory mode: copies into test directory
            return try await readTrack(from: copyFile(url))
        } else {
            // Production in-place reference mode: zero copying, original file untouched!
            let hasSecurityAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasSecurityAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let track = try await readTrack(from: url)
            try await saveTrackInPlace(track)
            return track
        }
    }

    func saveTrackInPlace(_ track: LocalTrack) async throws {
        var existingRecords: [PersistedTrackRecord] = []
        let manifestURL = try externalManifestURL()
        if let data = try? Data(contentsOf: manifestURL),
           let decoded = try? JSONDecoder().decode([PersistedTrackRecord].self, from: data) {
            existingRecords = decoded
        }

#if os(macOS)
        let bookmarkOptions: URL.BookmarkCreationOptions = .withSecurityScope
#else
        let bookmarkOptions: URL.BookmarkCreationOptions = []
#endif
        let bookmark = try? track.fileURL.bookmarkData(options: bookmarkOptions, includingResourceValuesForKeys: nil, relativeTo: nil)
        let newRecord = PersistedTrackRecord(
            fileURL: track.fileURL,
            bookmarkData: bookmark,
            title: track.title,
            artist: track.artist,
            album: track.album,
            duration: track.duration,
            artworkData: track.artworkData
        )

        if let idx = existingRecords.firstIndex(where: { $0.fileURL.standardizedFileURL == track.fileURL.standardizedFileURL }) {
            existingRecords[idx] = newRecord
        } else {
            existingRecords.append(newRecord)
        }

        let encoded = try JSONEncoder().encode(existingRecords)
        try encoded.write(to: manifestURL, options: .atomic)
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
            var isStale = false
#if os(macOS)
            let resolveOptions: URL.BookmarkResolutionOptions = .withSecurityScope
#else
            let resolveOptions: URL.BookmarkResolutionOptions = []
#endif
            if let bookmark = record.bookmarkData,
               let resolvedURL = try? URL(resolvingBookmarkData: bookmark, options: resolveOptions, relativeTo: nil, bookmarkDataIsStale: &isStale) {
                _ = resolvedURL.startAccessingSecurityScopedResource()
                tracks.append(LocalTrack(
                    fileURL: resolvedURL,
                    title: record.title,
                    artist: record.artist,
                    album: record.album,
                    duration: record.duration,
                    artworkData: record.artworkData
                ))
            } else {
                tracks.append(record.toLocalTrack())
            }
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
            let rule = await PathHeuristicRuleStore.shared.match(fileURL: url)
            let title = parsed.title
            let artist = rule?.targetArtist ?? parsed.artist ?? "Unknown Artist"
            let album = rule?.targetAlbum ?? parsed.album
            let artworkData = LocalArtworkExtractor.extractFromDirectory(folderURL: url.deletingLastPathComponent())

            return LocalTrack(
                fileURL: url,
                title: title,
                artist: artist,
                album: album,
                duration: dsfMeta.duration,
                artworkData: artworkData
            )
        }

        let metadata:
            [AVMetadataItem]


        do {

            metadata =
                try await asset.load(
                    .commonMetadata
                )

        } catch {

            metadata = []


            print(
                """
                Local Metadata △
                \(url.lastPathComponent)
                common metadata unavailable:
                \(error.localizedDescription)
                """
            )
        }


        // MARK: Title

        let parsed = FileNameHeuristicParser.parse(fileURL: url)
        let rule = await PathHeuristicRuleStore.shared.match(fileURL: url)

        // MARK: Title

        let rawTitle =
            await metadataString(
                identifier:
                    .commonIdentifierTitle,
                metadata:
                    metadata
            )
        let title = (rawTitle != nil && !rawTitle!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            ? rawTitle!
            : parsed.title


        // MARK: Artist

        let rawArtist =
            await metadataString(
                identifier:
                    .commonIdentifierArtist,
                metadata:
                    metadata
            )
        let artist: String
        if let rawArtist, !rawArtist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, rawArtist != "Unknown Artist" {
            artist = rawArtist
        } else {
            artist = rule?.targetArtist ?? parsed.artist ?? "Unknown Artist"
        }


        // MARK: Album

        let rawAlbum =
            await metadataString(
                identifier:
                    .commonIdentifierAlbumName,
                metadata:
                    metadata
            )
        let album = (rawAlbum != nil && !rawAlbum!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            ? rawAlbum
            : (rule?.targetAlbum ?? parsed.album)


        // MARK: Artwork

        var artworkData =
            await metadataData(
                identifier:
                    .commonIdentifierArtwork,
                metadata:
                    metadata
            )
        if artworkData == nil {
            artworkData = LocalArtworkExtractor.extractFromDirectory(folderURL: url.deletingLastPathComponent())
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
            title: \(title)
            artist: \(artist)
            album: \(album ?? "—")
            duration: \(duration)
            artwork: \(artworkData != nil)
            """
        )


        return LocalTrack(
            fileURL:
                url,
            title:
                title,
            artist:
                artist,
            album:
                album,
            duration:
                duration,
            artworkData:
                artworkData
        )
    }

    private static func metadataString(
        identifier:
            AVMetadataIdentifier,
        metadata:
            [AVMetadataItem]
    ) async -> String? {

        let items =
            AVMetadataItem
                .metadataItems(
                    from:
                        metadata,
                    filteredByIdentifier:
                        identifier
                )


        guard let item =
                items.first
        else {
            return nil
        }


        return try? await item.load(
            .stringValue
        )
    }


    private static func metadataData(
        identifier:
            AVMetadataIdentifier,
        metadata:
            [AVMetadataItem]
    ) async -> Data? {

        let items =
            AVMetadataItem
                .metadataItems(
                    from:
                        metadata,
                    filteredByIdentifier:
                        identifier
                )


        guard let item =
                items.first
        else {
            return nil
        }


        return try? await item.load(
            .dataValue
        )
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

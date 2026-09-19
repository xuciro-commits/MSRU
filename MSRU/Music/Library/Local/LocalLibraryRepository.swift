import Foundation
import AVFoundation

/// Local media I/O boundary. UI state and selection remain in the store/scene.
@MainActor
protocol LocalLibraryRepository {
    func loadTracks() async throws -> [LocalTrack]
    func importTrack(from url: URL) async throws -> LocalTrack?
}

@MainActor
final class FileLocalLibraryRepository: LocalLibraryRepository {
    private let directory: URL?

    init(directory: URL? = nil) {
        self.directory = directory
    }

    func loadTracks() async throws -> [LocalTrack] {
            let directory =
                try mediaDirectory()

            let urls =
                try FileManager
                    .default
                    .contentsOfDirectory(
                        at: directory,
                        includingPropertiesForKeys:
                            nil,
                        options: [
                            .skipsHiddenFiles
                        ]
                    )
                    .filter {
                        isSupported(
                            $0
                        )
                    }
                    .sorted {
                        $0.lastPathComponent
                            .localizedCaseInsensitiveCompare(
                                $1.lastPathComponent
                            )
                        == .orderedAscending
                    }


            var loadedTracks:
                [LocalTrack] = []


            for url in urls {

                do {

                    let track =
                        try await readTrack(
                            from: url
                        )

                    loadedTracks
                        .append(
                            track
                        )

                } catch {

                    print(
                        "Local metadata failed:",
                        url.lastPathComponent,
                        error.localizedDescription
                    )
                }
            }


            return loadedTracks
    }

    func importTrack(from url: URL) async throws -> LocalTrack? {
        guard isSupported(url) else { return nil }
        return try await readTrack(from: copyFile(url))
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

    private func readTrack(
        from url:
            URL
    ) async throws -> LocalTrack {
        let url = url.resolvingSymlinksInPath().standardizedFileURL

        let asset =
            AVURLAsset(
                url:
                    url
            )


        /*
         Metadata 是增强信息，不应该成为
         “这个文件是否允许进入 Library”的前置条件。

         特别是 DTS / 新格式 / Provider-backed media，
         系统可能能保存文件，但不一定能通过
         AVURLAsset 解析全部 metadata。
         */

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

        let title =
            await metadataString(
                identifier:
                    .commonIdentifierTitle,
                metadata:
                    metadata
            )
            ?? url
                .deletingPathExtension()
                .lastPathComponent


        // MARK: Artist

        let artist =
            await metadataString(
                identifier:
                    .commonIdentifierArtist,
                metadata:
                    metadata
            )
            ?? "Unknown Artist"


        // MARK: Album

        let album =
            await metadataString(
                identifier:
                    .commonIdentifierAlbumName,
                metadata:
                    metadata
            )


        // MARK: Artwork

        let artworkData =
            await metadataData(
                identifier:
                    .commonIdentifierArtwork,
                metadata:
                    metadata
            )


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

    private func metadataString(
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


    private func metadataData(
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

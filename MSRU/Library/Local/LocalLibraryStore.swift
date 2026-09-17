//
//  LocalLibraryStore.swift
//  MSRU
//

import Foundation
import AVFoundation
import Observation


@MainActor
@Observable
final class LocalLibraryStore {

    // MARK: - Content

    private(set) var tracks:
        [LocalTrack] = []


    // MARK: - State

    private(set) var isImporting =
        false

    private(set) var errorMessage:
        String?

    private var didLoad =
        false


    // MARK: - Supported Formats

    private let supportedExtensions:
        Set<String> = [
            "mp3",
            "m4a",
            "aac",
            "wav",
            "aif",
            "aiff",
            "caf",
            "flac",
            "mp4"
        ]


    // MARK: - Load Existing Library

    func loadIfNeeded()
        async {

        guard !didLoad else {
            return
        }

        didLoad = true

        await reload()
    }


    func reload()
        async {

        do {

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


            tracks =
                loadedTracks

        } catch {

            errorMessage =
                error.localizedDescription
        }
    }


    // MARK: - Import

    func importFiles(
        _ urls: [URL]
    ) async {

        guard !urls.isEmpty else {
            return
        }


        isImporting =
            true

        errorMessage =
            nil


        defer {
            isImporting = false
        }


        do {

            for sourceURL in urls {

                guard
                    isSupported(
                        sourceURL
                    )
                else {
                    continue
                }


                let destinationURL =
                    try importFile(
                        sourceURL
                    )


                let track =
                    try await readTrack(
                        from:
                            destinationURL
                    )


                if let index =
                    tracks.firstIndex(
                        where: {
                            $0.id
                                == track.id
                        }
                    ) {

                    tracks[index] =
                        track

                } else {

                    tracks.append(
                        track
                    )
                }
            }


            tracks.sort {
                $0.title
                    .localizedCaseInsensitiveCompare(
                        $1.title
                    )
                == .orderedAscending
            }

        } catch {

            errorMessage =
                error.localizedDescription

            print(
                "Local import failed:",
                error
            )
        }
    }


    // MARK: - Import File

    private func importFile(
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
        from url: URL
    ) async throws -> LocalTrack {

        let asset =
            AVURLAsset(
                url: url
            )


        let metadata =
            try await asset.load(
                .commonMetadata
            )


        let durationValue =
            try await asset.load(
                .duration
            )


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


        let artist =
            await metadataString(
                identifier:
                    .commonIdentifierArtist,
                metadata:
                    metadata
            )
            ?? "Unknown Artist"


        let album =
            await metadataString(
                identifier:
                    .commonIdentifierAlbumName,
                metadata:
                    metadata
            )


        let artworkData =
            await metadataData(
                identifier:
                    .commonIdentifierArtwork,
                metadata:
                    metadata
            )


        let seconds =
            durationValue.seconds


        let duration =
            seconds.isFinite
            ? seconds
            : 0


        print(
            """
            Local Metadata ✓
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

    private func mediaDirectory()
        throws -> URL {

        guard let applicationSupport =
                FileManager
                    .default
                    .urls(
                        for:
                            .applicationSupportDirectory,
                        in:
                            .userDomainMask
                    )
                    .first
        else {
            throw LocalLibraryError
                .applicationSupportUnavailable
        }


        let directory =
            applicationSupport
                .appendingPathComponent(
                    "MSRU",
                    isDirectory:
                        true
                )
                .appendingPathComponent(
                    "LocalMedia",
                    isDirectory:
                        true
                )


        try FileManager
            .default
            .createDirectory(
                at:
                    directory,
                withIntermediateDirectories:
                    true
            )


        return directory
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
        _ url: URL
    ) -> Bool {

        supportedExtensions
            .contains(
                url.pathExtension
                    .lowercased()
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

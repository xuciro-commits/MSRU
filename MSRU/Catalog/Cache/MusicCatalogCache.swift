//
//  MusicCatalogCache.swift
//  MSRU
//

import Foundation


actor MusicCatalogCache {

    // MARK: - Snapshot

    struct Snapshot:
        Sendable {

        let sections:
            [MusicSection]

        let fetchedAt:
            Date

        let isFresh:
            Bool
    }


    private struct CacheFile:
        Codable {

        let provider:
            MusicProviderID

        let fetchedAt:
            Date

        let sections:
            [MusicSection]
    }


    // MARK: - Configuration

    private let maximumAge:
        TimeInterval


    init(
        maximumAge: TimeInterval =
            24 * 60 * 60
    ) {
        self.maximumAge =
            maximumAge
    }


    // MARK: - Load

    func load(
        provider:
            MusicProviderID
    ) -> Snapshot? {

        do {

            let url =
                try cacheURL(
                    provider:
                        provider
                )


            guard
                FileManager
                    .default
                    .fileExists(
                        atPath:
                            url.path
                    )
            else {
                return nil
            }


            let data =
                try Data(
                    contentsOf:
                        url
                )


            let cacheFile =
                try JSONDecoder()
                    .decode(
                        CacheFile.self,
                        from:
                            data
                    )


            guard
                cacheFile.provider
                    == provider
            else {
                return nil
            }


            let age =
                Date()
                    .timeIntervalSince(
                        cacheFile
                            .fetchedAt
                    )


            return Snapshot(
                sections:
                    cacheFile.sections,
                fetchedAt:
                    cacheFile.fetchedAt,
                isFresh:
                    age < maximumAge
            )

        } catch {

            print(
                "Catalog Cache load failed:",
                error.localizedDescription
            )

            return nil
        }
    }


    // MARK: - Save

    func save(
        sections:
            [MusicSection],
        provider:
            MusicProviderID
    ) {

        guard !sections.isEmpty else {
            return
        }


        do {

            let url =
                try cacheURL(
                    provider:
                        provider
                )


            let cacheFile =
                CacheFile(
                    provider:
                        provider,
                    fetchedAt:
                        Date(),
                    sections:
                        sections
                )


            let encoder =
                JSONEncoder()

            encoder.outputFormatting = [
                .prettyPrinted,
                .sortedKeys
            ]


            let data =
                try encoder
                    .encode(
                        cacheFile
                    )


            try data.write(
                to:
                    url,
                options:
                    .atomic
            )


            print(
                "Catalog Cache ✓ saved",
                sections.count,
                "sections"
            )

        } catch {

            print(
                "Catalog Cache save failed:",
                error.localizedDescription
            )
        }
    }


    // MARK: - Clear

    func clear(
        provider:
            MusicProviderID
    ) {

        do {

            let url =
                try cacheURL(
                    provider:
                        provider
                )


            guard
                FileManager
                    .default
                    .fileExists(
                        atPath:
                            url.path
                    )
            else {
                return
            }


            try FileManager
                .default
                .removeItem(
                    at:
                        url
                )

        } catch {

            print(
                "Catalog Cache clear failed:",
                error.localizedDescription
            )
        }
    }


    // MARK: - URL

    private func cacheURL(
        provider:
            MusicProviderID
    ) throws -> URL {

        let fileManager =
            FileManager.default


        guard let applicationSupport =
                fileManager.urls(
                    for:
                        .applicationSupportDirectory,
                    in:
                        .userDomainMask
                )
                .first
        else {
            throw CacheError
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
                    "CatalogCache",
                    isDirectory:
                        true
                )


        try fileManager
            .createDirectory(
                at:
                    directory,
                withIntermediateDirectories:
                    true
            )


        return directory
            .appendingPathComponent(
                "\(provider.rawValue)-home.json"
            )
    }
}


// MARK: - Error

private enum CacheError:
    LocalizedError {

    case applicationSupportUnavailable


    var errorDescription:
        String? {

        switch self {

        case .applicationSupportUnavailable:
            "Application Support directory is unavailable."
        }
    }
}

//
//  JSONLibraryRepository.swift
//  MSRU
//

import Foundation


actor JSONLibraryRepository:
    LibraryRepository {

    private let fileURL:
        URL


    init(
        fileURL:
            URL? = nil
    ) {

        if let fileURL {

            self.fileURL =
                fileURL

            return
        }


        let fileManager =
            FileManager.default


        let baseURL =
            fileManager.urls(
                for:
                    .applicationSupportDirectory,
                in:
                    .userDomainMask
            )
            .first
            ?? fileManager
                .temporaryDirectory


        let directory =
            baseURL
                .appendingPathComponent(
                    "MSRU",
                    isDirectory:
                        true
                )


        try? fileManager
            .createDirectory(
                at:
                    directory,
                withIntermediateDirectories:
                    true
            )


        self.fileURL =
            directory
                .appendingPathComponent(
                    "Library.json",
                    isDirectory:
                        false
                )
    }


    // MARK: - Load

    func loadTracks()
        async throws
        -> [LibraryTrack] {

        guard
            FileManager.default
                .fileExists(
                    atPath:
                        fileURL.path
                )
        else {

            return []
        }


        let data =
            try Data(
                contentsOf:
                    fileURL
            )


        guard !data.isEmpty
        else {

            return []
        }


        let decoder =
            JSONDecoder()


        decoder.dateDecodingStrategy =
            .iso8601


        return try decoder
            .decode(
                [LibraryTrack].self,
                from:
                    data
            )
    }


    // MARK: - Save

    func saveTracks(
        _ tracks:
            [LibraryTrack]
    ) async throws {

        let encoder =
            JSONEncoder()


        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys
        ]


        encoder.dateEncodingStrategy =
            .iso8601


        let data =
            try encoder
                .encode(
                    tracks
                )


        /*
         Atomic Write：

         先写临时文件，
         完成后再替换正式文件。

         避免应用异常退出时
         把 Library.json 写坏。
         */
        try data.write(
            to:
                fileURL,
            options:
                .atomic
        )
    }
}

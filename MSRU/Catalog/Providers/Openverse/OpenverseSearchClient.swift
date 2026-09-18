//
//  OpenverseSearchClient.swift
//  MSRU
//

import Foundation


nonisolated struct OpenverseSearchClient:
    Sendable {

    let search:
        @Sendable (
            String
        ) async throws
        -> [OpenverseAudio]


    init(
        search:
            @escaping
            @Sendable (
                String
            ) async throws
            -> [OpenverseAudio]
    ) {

        self.search =
            search
    }
}


// MARK: - Live

nonisolated extension OpenverseSearchClient {

    static let live =
        OpenverseSearchClient {
            query in

            try await OpenverseCatalogProvider()
                .search(
                    query
                )
        }
}


// MARK: - Preview / Test

nonisolated extension OpenverseSearchClient {

    static func preview(
        results:
            [OpenverseAudio]
    ) -> Self {

        Self {
            query in

            let cleaned =
                query
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                    .lowercased()


            guard
                !cleaned.isEmpty
            else {
                return []
            }


            return results
                .filter {
                    item in

                    item.title
                        .lowercased()
                        .contains(
                            cleaned
                        )
                    ||
                    item.creatorTitle
                        .lowercased()
                        .contains(
                            cleaned
                        )
                }
        }
    }
}

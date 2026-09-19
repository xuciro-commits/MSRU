//
//  OpenverseCatalogProvider.swift
//  MSRU
//

import Foundation


nonisolated enum OpenverseCatalogError:
    LocalizedError,
    Sendable {

    case invalidRequest
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Unable to create the Openverse request."

        case .invalidResponse:
            return "Openverse returned an invalid response."

        case .httpStatus(let status):
            return "Openverse returned HTTP \(status)."
        }
    }
}


nonisolated struct OpenverseCatalogProvider:
    Sendable {

    private let baseURL =
        "https://api.openverse.org/v1/audio/"

    func search(
        _ query:
            String,
        pageSize:
            Int = 12
    ) async throws -> [OpenverseAudio] {

        let cleaned =
            query
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard !cleaned.isEmpty,
              var components =
                URLComponents(
                    string:
                        baseURL
                )
        else {
            return []
        }

        components.queryItems = [
            URLQueryItem(
                name:
                    "q",
                value:
                    cleaned
            ),
            URLQueryItem(
                name:
                    "page_size",
                value:
                    String(
                        max(
                            1,
                            min(
                                pageSize,
                                20
                            )
                        )
                    )
            )
        ]

        guard let url =
            components.url
        else {
            throw OpenverseCatalogError.invalidRequest
        }

        var request =
            URLRequest(
                url:
                    url
            )

        request.httpMethod =
            "GET"

        request.timeoutInterval =
            12

        request.setValue(
            "application/json",
            forHTTPHeaderField:
                "Accept"
        )

        request.setValue(
            "MSRU/0.1 OpenverseProvider",
            forHTTPHeaderField:
                "User-Agent"
        )

        let (
            data,
            response
        ) =
            try await URLSession.shared
                .data(
                    for:
                        request
                )

        guard let http =
            response
                as? HTTPURLResponse
        else {
            throw OpenverseCatalogError.invalidResponse
        }

        guard (200..<300)
            .contains(
                http.statusCode
            )
        else {
            throw OpenverseCatalogError.httpStatus(
                http.statusCode
            )
        }

        let decoded =
            try JSONDecoder()
                .decode(
                    OpenverseAudioSearchResponse.self,
                    from:
                        data
                )

        return decoded.results
            .filter {
                $0.mediaURL != nil
            }
            .sorted {
                lhs,
                rhs in

                if lhs.prefersNativePlayback
                    != rhs.prefersNativePlayback {

                    return lhs.prefersNativePlayback
                }

                return lhs.title
                    .localizedCaseInsensitiveCompare(
                        rhs.title
                    )
                    == .orderedAscending
            }
    }
}

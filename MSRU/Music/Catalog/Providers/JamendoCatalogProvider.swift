//
//  JamendoCatalogProvider.swift
//  MSRU
//

import Foundation


struct JamendoCatalogProvider:
    MusicCatalogProvider {

    let id:
        MusicProviderID = .jamendo


    /*
     Jamendo 官方文档公开提供的测试 Client ID。

     仅用于开发阶段。

     真正发布 MSRU 前，应在 Jamendo Developer Portal
     创建自己的 Application 并替换它。
     */

    private let clientID:
        String


    init(
        clientID: String = "709fa152"
    ) {
        self.clientID =
            clientID
    }


    // MARK: - Home

    func homeSections()
        async throws -> [MusicSection] {

        async let featured =
            fetchTracks(
                featured: true,
                limit: 12
            )


        async let popular =
            fetchTracks(
                order:
                    "popularity_month",
                limit: 20
            )


        async let electronic =
            fetchTracks(
                tags:
                    "electronic",
                limit: 20
            )


        async let rock =
            fetchTracks(
                tags:
                    "rock",
                limit: 20
            )


        let (
            featuredTracks,
            popularTracks,
            electronicTracks,
            rockTracks
        ) = try await (
            featured,
            popular,
            electronic,
            rock
        )


        return [
            MusicSection(
                id:
                    "jamendo-featured",
                title:
                    "Featured",
                subtitle:
                    "Selected music",
                layout:
                    .featured,
                items:
                    featuredTracks
            ),

            MusicSection(
                id:
                    "jamendo-popular",
                title:
                    "Popular Right Now",
                layout:
                    .shelf,
                items:
                    popularTracks
            ),

            MusicSection(
                id:
                    "jamendo-electronic",
                title:
                    "Electronic",
                layout:
                    .compactShelf,
                items:
                    electronicTracks
            ),

            MusicSection(
                id:
                    "jamendo-rock",
                title:
                    "Rock",
                layout:
                    .compactShelf,
                items:
                    rockTracks
            )
        ]
    }


    // MARK: - Search

    func search(
        _ query: String
    ) async throws -> [MusicContent] {

        try await fetchTracks(
            search:
                query,
            limit:
                40
        )
    }


    // MARK: - Tracks

    private func fetchTracks(
        search: String? = nil,
        tags: String? = nil,
        featured: Bool = false,
        order: String? = nil,
        limit: Int
    ) async throws -> [MusicContent] {

        var components =
            URLComponents(
                string:
                    "https://api.jamendo.com/v3.0/tracks/"
            )!


        var queryItems: [URLQueryItem] = [

            URLQueryItem(
                name: "client_id",
                value: clientID
            ),

            URLQueryItem(
                name: "format",
                value: "json"
            ),

            URLQueryItem(
                name: "limit",
                value:
                    String(limit)
            ),

            URLQueryItem(
                name: "imagesize",
                value: "600"
            ),

            URLQueryItem(
                name: "audioformat",
                value: "mp31"
            )
        ]


        if let search {
            queryItems.append(
                URLQueryItem(
                    name: "search",
                    value: search
                )
            )
        }


        if let tags {
            queryItems.append(
                URLQueryItem(
                    name: "tags",
                    value: tags
                )
            )
        }


        if featured {
            queryItems.append(
                URLQueryItem(
                    name: "featured",
                    value: "1"
                )
            )
        }


        if let order {
            queryItems.append(
                URLQueryItem(
                    name: "order",
                    value: order
                )
            )
        }


        components.queryItems =
            queryItems


        guard let url =
                components.url
        else {
            throw JamendoError.invalidURL
        }


        var request =
            URLRequest(
                url: url
            )

        request.timeoutInterval =
            30


        let (
            data,
            response
        ) = try await URLSession
            .shared
            .data(
                for: request
            )


        guard
            let http =
                response
                    as? HTTPURLResponse,
            200..<300 ~= http.statusCode
        else {
            throw JamendoError.invalidResponse
        }


        let payload =
            try JSONDecoder()
                .decode(
                    JamendoResponse.self,
                    from: data
                )


        guard
            payload.headers.status
                == "success"
        else {
            throw JamendoError.api(
                payload.headers
                    .errorMessage
            )
        }


        return payload.results.map {
            track in

            MusicContent(
                id:
                    "jamendo:\(track.id)",
                provider:
                    .jamendo,
                kind:
                    .track,
                title:
                    track.name,
                subtitle:
                    track.artistName,
                artworkURL:
                    URL(
                        string:
                            track.image
                    ),
                audioURL:
                    URL(
                        string:
                            track.audio
                    ),
                externalURL:
                    URL(
                        string:
                            track.shareURL
                    )
            )
        }
    }
}


// MARK: - Response

private struct JamendoResponse:
    Decodable {

    let headers:
        Headers

    let results:
        [Track]


    struct Headers:
        Decodable {

        let status:
            String

        let errorMessage:
            String


        enum CodingKeys:
            String,
            CodingKey {

            case status

            case errorMessage =
                "error_message"
        }
    }


    struct Track:
        Decodable {

        let id:
            String

        let name:
            String

        let artistName:
            String

        let image:
            String

        let audio:
            String

        let shareURL:
            String


        enum CodingKeys:
            String,
            CodingKey {

            case id
            case name

            case artistName =
                "artist_name"

            case image
            case audio

            case shareURL =
                "shareurl"
        }
    }
}


// MARK: - Error

private enum JamendoError:
    LocalizedError {

    case invalidURL
    case invalidResponse
    case api(String)


    var errorDescription:
        String? {

        switch self {

        case .invalidURL:
            "Invalid Jamendo URL."

        case .invalidResponse:
            "Jamendo returned an invalid response."

        case .api(let message):
            message.isEmpty
            ? "Jamendo API error."
            : message
        }
    }
}

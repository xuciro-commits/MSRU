//
//  MusicBrainzCatalogProvider.swift
//  MSRU
//

import Foundation


struct MusicBrainzCatalogProvider:
    MusicCatalogProvider {

    let id:
        MusicProviderID = .musicBrainz


    // MARK: - Configuration

    private let baseURL =
        URL(
            string:
                "https://musicbrainz.org/ws/2/"
        )!

    private let userAgent:
        String

    private let rateLimiter =
        MusicBrainzRateLimiter()


    init(
        userAgent: String =
            "MSRU/0.1 (local-development)"
    ) {
        self.userAgent =
            userAgent
    }


    // MARK: - Home

    func homeSections()
        async throws -> [MusicSection] {

        /*
         MusicBrainz:
         平均不要超过 1 request / second。

         这里必须保持顺序请求，
         不要改成 async let / TaskGroup。
         */

        var sections:
            [MusicSection] = []

        var lastError:
            Error?


        // Electronic

        do {

            let items =
                try await fetchReleaseGroups(
                    query:
                        "primarytype:album AND tag:electronic",
                    limit:
                        16
                )

            if !items.isEmpty {

                sections.append(
                    MusicSection(
                        id:
                            "musicbrainz-electronic",
                        title:
                            "Electronic",
                        subtitle:
                            "Albums from MusicBrainz",
                        layout:
                            .featured,
                        items:
                            items
                    )
                )
            }

        } catch {

            lastError = error

            print(
                "MusicBrainz Electronic failed:",
                error.localizedDescription
            )
        }


        // Rock

        do {

            let items =
                try await fetchReleaseGroups(
                    query:
                        "primarytype:album AND tag:rock",
                    limit:
                        18
                )

            if !items.isEmpty {

                sections.append(
                    MusicSection(
                        id:
                            "musicbrainz-rock",
                        title:
                            "Rock",
                        layout:
                            .shelf,
                        items:
                            items
                    )
                )
            }

        } catch {

            lastError = error

            print(
                "MusicBrainz Rock failed:",
                error.localizedDescription
            )
        }


        // Pop

        do {

            let items =
                try await fetchReleaseGroups(
                    query:
                        "primarytype:album AND tag:pop",
                    limit:
                        18
                )

            if !items.isEmpty {

                sections.append(
                    MusicSection(
                        id:
                            "musicbrainz-pop",
                        title:
                            "Pop",
                        layout:
                            .compactShelf,
                        items:
                            items
                    )
                )
            }

        } catch {

            lastError = error

            print(
                "MusicBrainz Pop failed:",
                error.localizedDescription
            )
        }


        // Jazz

        do {

            let items =
                try await fetchReleaseGroups(
                    query:
                        "primarytype:album AND tag:jazz",
                    limit:
                        18
                )

            if !items.isEmpty {

                sections.append(
                    MusicSection(
                        id:
                            "musicbrainz-jazz",
                        title:
                            "Jazz",
                        layout:
                            .compactShelf,
                        items:
                            items
                    )
                )
            }

        } catch {

            lastError = error

            print(
                "MusicBrainz Jazz failed:",
                error.localizedDescription
            )
        }


        /*
         只要任何一组成功，
         整个 Home 就认为加载成功。

         这样 MusicBrainz 某个请求临时 503，
         不会毁掉前面已经成功的数据。
         */

        if !sections.isEmpty {

            print(
                "MusicBrainz Home ✓",
                sections.count,
                "sections"
            )

            return sections
        }


        /*
         四组全部失败才真正 throw。
         */

        if let lastError {
            throw lastError
        }


        throw MusicBrainzError.noContent
    }


    // MARK: - Search

    func search(
        _ query: String
    ) async throws -> [MusicContent] {

        let trimmed =
            query.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )


        guard !trimmed.isEmpty else {
            return []
        }


        return try await fetchReleaseGroups(
            query:
                trimmed,
            limit:
                40
        )
    }


    // MARK: - Release Groups

    private func fetchReleaseGroups(
        query: String,
        limit: Int
    ) async throws -> [MusicContent] {

        var components =
            URLComponents(
                url:
                    baseURL
                        .appendingPathComponent(
                            "release-group/"
                        ),
                resolvingAgainstBaseURL:
                    false
            )


        components?.queryItems = [

            URLQueryItem(
                name:
                    "query",
                value:
                    query
            ),

            URLQueryItem(
                name:
                    "fmt",
                value:
                    "json"
            ),

            URLQueryItem(
                name:
                    "limit",
                value:
                    String(
                        min(
                            max(limit, 1),
                            100
                        )
                    )
            )
        ]


        guard let url =
                components?.url
        else {
            throw MusicBrainzError
                .invalidURL
        }


        /*
         所有 MusicBrainz metadata 请求
         都必须先经过同一个 limiter。
         */

        await rateLimiter
            .wait()


        var request =
            URLRequest(
                url: url
            )

        request.timeoutInterval =
            30

        request.setValue(
            userAgent,
            forHTTPHeaderField:
                "User-Agent"
        )

        request.setValue(
            "application/json",
            forHTTPHeaderField:
                "Accept"
        )


        print(
            "MusicBrainz →",
            url.absoluteString
        )


        let (
            data,
            response
        ) = try await URLSession
            .shared
            .data(
                for: request
            )


        guard let http =
                response
                    as? HTTPURLResponse
        else {
            throw MusicBrainzError
                .invalidResponse
        }


        guard
            200..<300 ~= http.statusCode
        else {

            let body =
                String(
                    data:
                        data,
                    encoding:
                        .utf8
                )

            throw MusicBrainzError
                .http(
                    statusCode:
                        http.statusCode,
                    body:
                        body
                )
        }


        let payload =
            try JSONDecoder()
                .decode(
                    MusicBrainzReleaseGroupResponse.self,
                    from:
                        data
                )


        print(
            "MusicBrainz ✓",
            payload.releaseGroups.count,
            "items"
        )


        return payload
            .releaseGroups
            .map {
                releaseGroup in

                makeContent(
                    from:
                        releaseGroup
                )
            }
    }


    // MARK: - Mapping

    private func makeContent(
        from releaseGroup:
            MusicBrainzReleaseGroup
    ) -> MusicContent {

        let artistName =
            releaseGroup
                .artistCredit
                .map(\.name)
                .joined(
                    separator:
                        ", "
                )


        /*
         Cover Art Archive 可以直接通过
         Release Group MBID 请求封面。

         没有封面时 AsyncImage 会 failure，
         MusicArtworkView 会显示 placeholder。
         */

        let artworkURL =
            URL(
                string:
                    "https://coverartarchive.org/release-group/\(releaseGroup.id)/front-500"
            )


        let externalURL =
            URL(
                string:
                    "https://musicbrainz.org/release-group/\(releaseGroup.id)"
            )


        return MusicContent(
            id:
                "musicbrainz:\(releaseGroup.id)",
            provider:
                .musicBrainz,
            kind:
                .album,
            title:
                releaseGroup.title,
            subtitle:
                artistName.isEmpty
                ? releaseGroup.firstReleaseDate
                : artistName,
            artworkURL:
                artworkURL,
            audioURL:
                nil,
            externalURL:
                externalURL
        )
    }
}


// MARK: - Rate Limiter

private actor MusicBrainzRateLimiter {

    /*
     官方限制平均 <= 1 req/s。

     用 1.25 秒，
     给网络调度、多个入口等留一些余量。
     */

    private let interval:
        TimeInterval = 1.25

    private var nextAllowedRequest:
        Date = .distantPast


    func wait()
        async {

        let now =
            Date()

        let scheduledDate =
            max(
                now,
                nextAllowedRequest
            )


        nextAllowedRequest =
            scheduledDate
                .addingTimeInterval(
                    interval
                )


        let delay =
            scheduledDate
                .timeIntervalSince(
                    now
                )


        guard delay > 0 else {
            return
        }


        let nanoseconds =
            UInt64(
                delay
                * 1_000_000_000
            )


        try? await Task.sleep(
            nanoseconds:
                nanoseconds
        )
    }
}


// MARK: - API Models

private struct MusicBrainzReleaseGroupResponse:
    Decodable {

    let created:
        String?

    let count:
        Int

    let offset:
        Int

    let releaseGroups:
        [MusicBrainzReleaseGroup]


    enum CodingKeys:
        String,
        CodingKey {

        case created
        case count
        case offset

        case releaseGroups =
            "release-groups"
    }
}


private struct MusicBrainzReleaseGroup:
    Decodable {

    let id:
        String

    let title:
        String

    let firstReleaseDate:
        String?

    let primaryType:
        String?

    let artistCredit:
        [MusicBrainzArtistCredit]


    enum CodingKeys:
        String,
        CodingKey {

        case id
        case title

        case firstReleaseDate =
            "first-release-date"

        case primaryType =
            "primary-type"

        case artistCredit =
            "artist-credit"
    }
}


private struct MusicBrainzArtistCredit:
    Decodable {

    let name:
        String

    let artist:
        MusicBrainzArtist?
}


private struct MusicBrainzArtist:
    Decodable {

    let id:
        String

    let name:
        String

    let sortName:
        String?


    enum CodingKeys:
        String,
        CodingKey {

        case id
        case name

        case sortName =
            "sort-name"
    }
}


// MARK: - Errors

private enum MusicBrainzError:
    LocalizedError {

    case invalidURL

    case invalidResponse

    case noContent

    case http(
        statusCode: Int,
        body: String?
    )


    var errorDescription:
        String? {

        switch self {

        case .invalidURL:

            return
                "Could not create the MusicBrainz URL."


        case .invalidResponse:

            return
                "MusicBrainz returned an invalid response."


        case .noContent:

            return
                "MusicBrainz did not return any usable content."


        case .http(
            let statusCode,
            let body
        ):

            if let body,
               !body.isEmpty {

                return
                    """
                    MusicBrainz returned HTTP \(statusCode).

                    \(body)
                    """
            }


            return
                "MusicBrainz returned HTTP \(statusCode)."
        }
    }
}

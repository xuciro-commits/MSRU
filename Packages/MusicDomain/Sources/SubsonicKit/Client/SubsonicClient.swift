//
//  SubsonicClient.swift
//  SubsonicKit
//
//  Actor network client executing Subsonic and OpenSubsonic REST requests.
//

import Foundation
import os

public actor SubsonicClient {
    public nonisolated let serverID: LibrarySourceID
    public nonisolated let baseURL: URL
    public nonisolated let username: String
    private nonisolated let credentialStore: SubsonicCredentialStore
    private nonisolated let authenticator: SubsonicAuthenticator
    private let session: URLSession

    private static let logger = Logger(subsystem: "com.msru.subsonic", category: "network")

    public init(
        serverID: LibrarySourceID,
        baseURL: URL,
        username: String,
        credentialStore: SubsonicCredentialStore,
        authenticator: SubsonicAuthenticator = SubsonicAuthenticator(),
        session: URLSession = .shared
    ) {
        self.serverID = serverID
        self.baseURL = baseURL
        self.username = username
        self.credentialStore = credentialStore
        self.authenticator = authenticator
        self.session = session
    }

    // MARK: - URL Construction

    public nonisolated func buildAuthenticatedURL(for endpoint: SubsonicEndpoint) throws -> URL {
        let normalizedBase: URL
        let baseString = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if baseString.hasSuffix("/rest") {
            normalizedBase = URL(string: "\(baseString)/") ?? baseURL
        } else {
            normalizedBase = URL(string: "\(baseString)/rest/") ?? baseURL
        }

        let endpointURL = normalizedBase.appendingPathComponent(endpoint.path)

        guard endpoint.requiresAuthentication else {
            var comps = URLComponents(url: endpointURL, resolvingAgainstBaseURL: false) ?? URLComponents()
            var items = endpoint.queryItems
            items.append(contentsOf: [
                URLQueryItem(name: "u", value: username),
                URLQueryItem(name: "v", value: "1.16.1"),
                URLQueryItem(name: "c", value: "msru"),
                URLQueryItem(name: "f", value: "json")
            ])
            comps.queryItems = items
            guard let finalURL = comps.url else {
                throw RemoteLibraryError.invalidURL(url: endpointURL)
            }
            return finalURL
        }

        guard let password = try credentialStore.password(for: serverID), !password.isEmpty else {
            throw RemoteLibraryError.authenticationFailed(message: "Password missing in credentials store for \(serverID.rawValue)")
        }

        return authenticator.sign(
            url: endpointURL,
            username: username,
            password: password,
            extraQueryItems: endpoint.queryItems
        )
    }

    // MARK: - Generic Request

    private func execute<T: Codable & Sendable>(
        endpoint: SubsonicEndpoint,
        timeout: TimeInterval = 15.0
    ) async throws -> SubsonicResponse<T> {
        let requestURL = try buildAuthenticatedURL(for: endpoint)

        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout

        Self.logger.debug("[Subsonic] Requesting endpoint=\(endpoint.path, privacy: .public) server=\(self.serverID.rawValue, privacy: .public)")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            switch urlError.code {
            case .timedOut:
                throw RemoteLibraryError.timedOut
            case .cannotConnectToHost, .cannotFindHost, .notConnectedToInternet:
                throw RemoteLibraryError.unreachable(serverURL: baseURL)
            case .cancelled:
                throw RemoteLibraryError.operationCancelled
            default:
                throw RemoteLibraryError.serverError(code: urlError.errorCode, message: urlError.localizedDescription)
            }
        } catch {
            throw RemoteLibraryError.serverError(code: -1, message: error.localizedDescription)
        }

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw RemoteLibraryError.authenticationFailed(message: "HTTP \(httpResponse.statusCode)")
            }
            throw RemoteLibraryError.serverError(code: httpResponse.statusCode, message: "HTTP error")
        }

        do {
            let decoder = JSONDecoder()
            let envelope = try decoder.decode(SubsonicResponseEnvelope<T>.self, from: data)
            let root = envelope.subsonicResponse

            if !root.isSuccess {
                if let error = root.error {
                    if error.code == 40 || error.code == 41 {
                        throw RemoteLibraryError.authenticationFailed(message: error.message)
                    }
                    throw RemoteLibraryError.serverError(code: error.code, message: error.message)
                }
                throw RemoteLibraryError.serverError(code: -1, message: "Subsonic operation failed with status \(root.status)")
            }

            return root
        } catch let err as RemoteLibraryError {
            throw err
        } catch {
            throw RemoteLibraryError.malformedResponse(details: error.localizedDescription)
        }
    }

    // MARK: - API Methods

    public func ping() async throws -> SubsonicServerInfo {
        let response: SubsonicResponse<EmptyData> = try await execute(endpoint: .ping, timeout: 5.0)

        // Try probing OpenSubsonic extensions if server indicates openSubsonic
        var extensions: [OpenSubsonicExtensionDTO] = []
        var isOpenSubsonic = response.openSubsonic == true

        if isOpenSubsonic {
            if let extList = try? await self.openSubsonicExtensions() {
                extensions = extList
            }
        } else {
            // Also try probing directly in case header was omitted
            if let extList = try? await self.openSubsonicExtensions(), !extList.isEmpty {
                extensions = extList
                isOpenSubsonic = true
            }
        }

        return SubsonicServerInfo(
            apiVersion: response.version,
            serverType: response.type,
            serverVersion: response.serverVersion,
            isOpenSubsonic: isOpenSubsonic,
            openSubsonicExtensions: extensions
        )
    }

    public func openSubsonicExtensions() async throws -> [OpenSubsonicExtensionDTO] {
        let response: SubsonicResponse<OpenSubsonicExtensionsContainer> = try await execute(
            endpoint: .getOpenSubsonicExtensions,
            timeout: 5.0
        )
        return response.data?.openSubsonicExtensions ?? []
    }

    public func artists() async throws -> [SubsonicArtistDTO] {
        let response: SubsonicResponse<SubsonicArtistsID3Container> = try await execute(endpoint: .getArtists)
        guard let index = response.data?.artists?.index else {
            return []
        }
        return index.flatMap(\.artist)
    }

    public func artist(id: String) async throws -> SubsonicArtistDTO {
        let response: SubsonicResponse<SubsonicArtistID3Container> = try await execute(endpoint: .getArtist(id: id))
        guard let artist = response.data?.artist else {
            throw RemoteLibraryError.resourceNotFound(id: id)
        }
        return artist
    }

    public func album(id: String) async throws -> SubsonicAlbumDTO {
        let response: SubsonicResponse<SubsonicAlbumID3Container> = try await execute(endpoint: .getAlbum(id: id))
        guard let album = response.data?.album else {
            throw RemoteLibraryError.resourceNotFound(id: id)
        }
        return album
    }

    public func song(id: String) async throws -> SubsonicSongDTO {
        let response: SubsonicResponse<SubsonicSongContainer> = try await execute(endpoint: .getSong(id: id))
        guard let song = response.data?.song else {
            throw RemoteLibraryError.resourceNotFound(id: id)
        }
        return song
    }

    public func albumList2(type: String = "alphabeticalByName", size: Int = 500, offset: Int = 0) async throws -> [SubsonicAlbumDTO] {
        let response: SubsonicResponse<SubsonicAlbumList2Container> = try await execute(
            endpoint: .getAlbumList2(type: type, size: size, offset: offset)
        )
        return response.data?.albumList2?.album ?? []
    }

    public func search3(query: String, artistCount: Int = 20, albumCount: Int = 50, songCount: Int = 100) async throws -> SubsonicSearchResult3Payload {
        let response: SubsonicResponse<SubsonicSearchResult3Container> = try await execute(
            endpoint: .search3(query: query, artistCount: artistCount, albumCount: albumCount, songCount: songCount)
        )
        return response.data?.searchResult3 ?? SubsonicSearchResult3Payload(artist: [], album: [], song: [])
    }

    public func playlists() async throws -> [SubsonicPlaylistDTO] {
        let response: SubsonicResponse<SubsonicPlaylistsContainer> = try await execute(endpoint: .getPlaylists)
        return response.data?.playlists?.playlist ?? []
    }

    public func playlist(id: String) async throws -> SubsonicPlaylistDTO {
        let response: SubsonicResponse<SubsonicPlaylistContainer> = try await execute(endpoint: .getPlaylist(id: id))
        guard let pl = response.data?.playlist else {
            throw RemoteLibraryError.resourceNotFound(id: id)
        }
        return pl
    }

    public nonisolated func coverArtURL(id: String, size: Int? = nil) throws -> URL {
        try buildAuthenticatedURL(for: .getCoverArt(id: id, size: size))
    }

    public nonisolated func streamURL(id: String, format: String? = nil, maxBitRate: Int? = nil) throws -> URL {
        try buildAuthenticatedURL(for: .stream(id: id, format: format, maxBitRate: maxBitRate))
    }

    @available(*, deprecated, message: "Use streamURL(id:format:maxBitRate:) instead.")
    public nonisolated func streamURL(id: String, raw: Bool) throws -> URL {
        try streamURL(id: id, format: raw ? "raw" : nil)
    }

    public func star(id: String? = nil, albumId: String? = nil, artistId: String? = nil) async throws {
        let _: SubsonicResponse<EmptyData> = try await execute(endpoint: .star(id: id, albumId: albumId, artistId: artistId))
    }

    public func unstar(id: String? = nil, albumId: String? = nil, artistId: String? = nil) async throws {
        let _: SubsonicResponse<EmptyData> = try await execute(endpoint: .unstar(id: id, albumId: albumId, artistId: artistId))
    }

    public func scrobble(id: String, time: Double? = nil, submission: Bool = true) async throws {
        let _: SubsonicResponse<EmptyData> = try await execute(endpoint: .scrobble(id: id, time: time, submission: submission))
    }

    /// Fetches structured lyrics for a song by its ID (OpenSubsonic `getLyricsBySongId` extension).
    /// Returns the best available lyrics entry (synced preferred over plain), or nil.
    public func getLyricsBySongId(id: String) async throws -> SubsonicStructuredLyricsDTO? {
        let response: SubsonicResponse<SubsonicLyricsByIdContainer> = try await execute(
            endpoint: .getLyricsBySongId(id: id),
            timeout: 10.0
        )
        guard let entries = response.data?.lyricsList?.structuredLyrics, !entries.isEmpty else {
            return nil
        }
        // Ignore empty entries, then prefer synchronized lyrics.
        let available = entries.filter { $0.toLrcText() != nil }
        return available.first(where: { $0.synced == true }) ?? available.first
    }
}

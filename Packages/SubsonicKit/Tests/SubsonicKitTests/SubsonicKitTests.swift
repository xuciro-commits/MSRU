//
//  SubsonicKitTests.swift
//  SubsonicKitTests
//

import Testing
import Foundation
import CryptoKit
@testable import MediaLibrary
@testable import SubsonicKit

@Suite("Subsonic Authentication Contracts")
struct SubsonicAuthenticationTests {

    @Test("SubsonicAuthenticator computes deterministic MD5 token matching specification")
    func md5TokenComputation() {
        // Standard Subsonic spec example: password="sesame", salt="c1622f7d"
        let password = "sesame"
        let salt = "c1622f7d"
        let token = SubsonicAuthenticator.computeToken(password: password, salt: salt)

        // Manual verification of MD5("sesamec1622f7d")
        let expectedDigest = Insecure.MD5.hash(data: Data("sesamec1622f7d".utf8))
        let expectedHex = expectedDigest.map { String(format: "%02x", $0) }.joined()

        #expect(token == expectedHex)
        #expect(token.count == 32)
    }

    @Test("SubsonicAuthenticator produces required parameters and signs URL")
    func authenticatorSigning() {
        let auth = SubsonicAuthenticator(clientVersion: "1.16.1", clientName: "MSRU")
        let baseURL = URL(string: "http://192.168.31.200:8025/rest/ping.view")!
        let signedURL = auth.sign(url: baseURL, username: "msru", password: "msruz4pro")

        let components = URLComponents(url: signedURL, resolvingAgainstBaseURL: false)
        let items = components?.queryItems ?? []

        #expect(items.first(where: { $0.name == "u" })?.value == "msru")
        #expect(items.first(where: { $0.name == "v" })?.value == "1.16.1")
        #expect(items.first(where: { $0.name == "c" })?.value == "MSRU")
        #expect(items.first(where: { $0.name == "f" })?.value == "json")
        #expect(items.first(where: { $0.name == "t" })?.value != nil)
        #expect(items.first(where: { $0.name == "s" })?.value != nil)
    }

    @Test("CredentialStore saves, retrieves, and deletes passwords")
    func credentialStoreLifecycle() throws {
        let store = InMemorySubsonicCredentialStore()
        let sourceID = LibrarySourceID("zspace.home")

        #expect(try store.password(for: sourceID) == nil)

        try store.savePassword("msruz4pro", for: sourceID)
        #expect(try store.password(for: sourceID) == "msruz4pro")

        try store.deletePassword(for: sourceID)
        #expect(try store.password(for: sourceID) == nil)
    }
}

@Suite("Subsonic Mapper & DTO Contracts")
struct SubsonicMapperTests {

    @Test("SubsonicMapper converts SongDTO to UnifiedTrack with correct types")
    func songMapping() {
        let sourceID = LibrarySourceID("subsonic.test")
        let mapper = SubsonicMapper(sourceID: sourceID)

        let songDTO = SubsonicSongDTO(
            id: "12345",
            title: "七里香",
            album: "七里香",
            artist: "周杰伦",
            track: 1,
            year: 2004,
            genre: "Pop",
            coverArt: "al-123",
            size: 45000000,
            contentType: "audio/flac",
            suffix: "flac",
            duration: 299,
            bitRate: 1411,
            albumId: "al-123",
            artistId: "ar-99"
        )

        let track = mapper.mapSong(songDTO)

        #expect(track.id == MediaID(sourceID: sourceID, rawValue: "12345"))
        #expect(track.title == "七里香")
        #expect(track.artist == "周杰伦")
        #expect(track.artistID == MediaID(sourceID: sourceID, rawValue: "ar-99"))
        #expect(track.albumID == MediaID(sourceID: sourceID, rawValue: "al-123"))
        #expect(track.year == 2004)
        #expect(track.codec == "FLAC")
        #expect(track.duration == 299)
        #expect(track.artworkReference == "al-123")
    }

    @Test("SubsonicMapper handles missing album/artist gracefully")
    func albumMappingWithMissingFields() {
        let sourceID = LibrarySourceID("subsonic.test")
        let mapper = SubsonicMapper(sourceID: sourceID)

        let albumDTO = SubsonicAlbumDTO(
            id: "al-999",
            name: "Fallback Title",
            title: nil,
            artist: nil,
            artistId: nil
        )

        let album = mapper.mapAlbum(albumDTO)
        #expect(album.id.rawValue == "al-999")
        #expect(album.title == "Fallback Title")
        #expect(album.artist == "Unknown Artist")
        #expect(album.artistID == nil)
    }
}

// MARK: - Mock URLProtocol for Offline Fixture Testing

final class MockSubsonicURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var mockHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.mockHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

@Suite("Subsonic Client & Fixture Contracts", .serialized)
struct SubsonicClientTests {

    private func makeClient(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> (SubsonicClient, InMemorySubsonicCredentialStore) {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockSubsonicURLProtocol.self]
        let session = URLSession(configuration: config)

        MockSubsonicURLProtocol.mockHandler = handler

        let sourceID = LibrarySourceID("subsonic.mock")
        let credStore = InMemorySubsonicCredentialStore()
        try? credStore.savePassword("testpass", for: sourceID)

        let client = SubsonicClient(
            serverID: sourceID,
            baseURL: URL(string: "http://mock-subsonic:8025")!,
            username: "testuser",
            credentialStore: credStore,
            session: session
        )
        return (client, credStore)
    }

    @Test("getLyricsBySongId uses the authenticated song ID and prefers usable synced lyrics")
    func lyricsBySongID() async throws {
        let (client, _) = makeClient { request in
            let url = try #require(request.url)
            #expect(url.path.hasSuffix("/getLyricsBySongId.view"))
            #expect(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "id" })?.value == "song-42")
            let json = """
            {"subsonic-response":{"status":"ok","version":"1.16.1","lyricsList":{"structuredLyrics":[
              {"synced":true,"line":[]},
              {"synced":false,"line":[{"value":"Plain text"}]},
              {"synced":true,"offset":500,"line":[{"start":1000,"value":"Timed text"}]}
            ]}}}
            """
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(json.utf8))
        }

        let lyrics = try await client.getLyricsBySongId(id: "song-42")
        #expect(lyrics?.synced == true)
        #expect(lyrics?.toLrcText() == "[offset:500]\n[00:01.00]Timed text")
    }

    @Test("SubsonicClient ping successfully decodes server info and OpenSubsonic extensions")
    func pingAndOpenSubsonicExtensions() async throws {
        let (client, _) = makeClient { request in
            let path = request.url?.path ?? ""
            let url = request.url!

            if path.contains("ping.view") {
                let json = """
                {
                  "subsonic-response": {
                    "status": "ok",
                    "version": "1.16.1",
                    "type": "zspace",
                    "serverVersion": "3.1.0",
                    "openSubsonic": true
                  }
                }
                """
                let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (resp, Data(json.utf8))
            } else if path.contains("getOpenSubsonicExtensions.view") {
                let json = """
                {
                  "subsonic-response": {
                    "status": "ok",
                    "version": "1.16.1",
                    "openSubsonic": true,
                    "openSubsonicExtensions": [
                      { "name": "transcodeFree", "versions": [1] },
                      { "name": "formPost", "versions": [1] }
                    ]
                  }
                }
                """
                let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (resp, Data(json.utf8))
            }

            let resp = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }

        let info = try await client.ping()
        #expect(info.apiVersion == "1.16.1")
        #expect(info.serverType == "zspace")
        #expect(info.isOpenSubsonic == true)
        #expect(info.openSubsonicExtensions.count == 2)
        #expect(info.openSubsonicExtensions.first?.name == "transcodeFree")
    }

    @Test("SubsonicClient maps Subsonic error response to RemoteLibraryError")
    func errorMapping() async {
        let (client, _) = makeClient { request in
            let json = """
            {
              "subsonic-response": {
                "status": "failed",
                "version": "1.16.1",
                "error": {
                  "code": 40,
                  "message": "Wrong username or password"
                }
              }
            }
            """
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }

        do {
            _ = try await client.ping()
            Issue.record("Expected authentication error to be thrown")
        } catch let err as RemoteLibraryError {
            if case .authenticationFailed(let message) = err {
                #expect(message == "Wrong username or password")
            } else {
                Issue.record("Expected .authenticationFailed, got \(err)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("SubsonicCapabilityProbe probes client and generates full capabilities")
    func capabilityProbing() async throws {
        let (client, _) = makeClient { request in
            let json = """
            {
              "subsonic-response": {
                "status": "ok",
                "version": "1.16.1",
                "openSubsonic": true,
                "openSubsonicExtensions": [
                  { "name": "transcodeFree", "versions": [1] }
                ]
              }
            }
            """
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }

        let probe = SubsonicCapabilityProbe()
        let (info, caps) = try await probe.probe(client: client)

        #expect(info.isOpenSubsonic)
        #expect(caps.contains(.browse))
        #expect(caps.contains(.streaming))
        #expect(caps.contains(.openSubsonicExtensions))
    }
}

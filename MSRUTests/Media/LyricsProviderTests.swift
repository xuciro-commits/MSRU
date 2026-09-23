import Foundation
import Testing
import AppFoundation
import MediaLibrary
import SubsonicKit
@testable import MSRU

private final class LyricsURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestedSongID: String?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requestedSongID = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "id" })?.value
        let body = """
        {"subsonic-response":{"status":"ok","version":"1.16.1","lyricsList":{"structuredLyrics":[{"synced":true,"line":[{"start":1250,"value":"Remote line"}]}]}}}
        """
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@Suite("Lyrics provider chain")
struct LyricsProviderTests {
    actor CallLog {
        var names: [String] = []
        func record(_ name: String) { names.append(name) }
    }

    nonisolated struct StubProvider: LyricsProvider {
        let providerName: String
        let result: String?
        let fails: Bool
        let log: CallLog

        func fetchLyrics(context: LyricsQueryContext) async throws -> String? {
            await log.record(providerName)
            if fails { throw URLError(.badServerResponse) }
            return result
        }
    }

    @Test("A failed or empty provider falls through, and a valid result ends the chain")
    func fallbackAndFirstValidResult() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let log = CallLog()
        let providers: [any LyricsProvider] = [
            StubProvider(providerName: "error", result: nil, fails: true, log: log),
            StubProvider(providerName: "empty", result: "  ", fails: false, log: log),
            StubProvider(providerName: "success", result: "[00:01.00]First line", fails: false, log: log),
            StubProvider(providerName: "unused", result: "[00:02.00]Second line", fails: false, log: log)
        ]
        let service = LyricsService(providers: providers, cacheDirectory: directory)
        let document = await service.resolveLyrics(context: LyricsQueryContext(title: "Song", artist: "Artist"))

        #expect(document?.lines.first?.text == "First line")
        #expect(await log.names == ["error", "empty", "success"])
        let cacheURL = CachedLyricsProvider.cacheFileURL(title: "Song", artist: "Artist", cacheDirectory: directory)
        #expect(try String(contentsOf: cacheURL, encoding: .utf8) == "[00:01.00]First line")
    }

    @Test("Companion and cache providers read their matching files")
    func localFiles() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let audioURL = directory.appendingPathComponent("recording.flac")
        let sidecarURL = directory.appendingPathComponent("recording.lrc")
        try "[00:03.00]Sidecar".write(to: sidecarURL, atomically: true, encoding: .utf8)
        let context = LyricsQueryContext(title: "Song", artist: "Artist", fileURL: audioURL)
        #expect(try await LocalCompanionLyricsProvider().fetchLyrics(context: context) == "[00:03.00]Sidecar")

        let cacheURL = CachedLyricsProvider.cacheFileURL(title: "Song", artist: "Artist", cacheDirectory: directory)
        try "[00:04.00]Cached".write(to: cacheURL, atomically: true, encoding: .utf8)
        #expect(try await CachedLyricsProvider(cacheDirectory: directory).fetchLyrics(context: context) == "[00:04.00]Cached")
    }

    @Test("Subsonic provider requires both song and server identities")
    func subsonicIdentityGuard() async throws {
        let provider = SubsonicLyricsProvider(registry: LibraryProviderRegistry())
        #expect(try await provider.fetchLyrics(context: LyricsQueryContext(title: "Song", artist: "Artist")) == nil)
        #expect(try await provider.fetchLyrics(context: LyricsQueryContext(title: "Song", artist: "Artist", subsonicSongID: "42")) == nil)
        #expect(try await provider.fetchLyrics(context: LyricsQueryContext(title: "Song", artist: "Artist", subsonicSongID: "42", sourceID: "unknown")) == nil)
    }

    @Test("Subsonic provider queries the client registered for the song's server")
    func subsonicRoute() async throws {
        let sourceID = LibrarySourceID("lyrics-server")
        let credentials = InMemorySubsonicCredentialStore()
        try credentials.savePassword("test", for: sourceID)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LyricsURLProtocol.self]
        let client = SubsonicClient(
            serverID: sourceID,
            baseURL: URL(string: "https://lyrics.example")!,
            username: "tester",
            credentialStore: credentials,
            session: URLSession(configuration: configuration)
        )
        let registry = LibraryProviderRegistry()
        registry.register(SubsonicLibraryProvider(
            sourceID: sourceID,
            sourceName: "Test server",
            serverURL: URL(string: "https://lyrics.example")!,
            username: "tester",
            client: client
        ))
        let context = LyricsQueryContext(title: "Song", artist: "Artist", subsonicSongID: "song-42", sourceID: sourceID.rawValue)
        let text = try await SubsonicLyricsProvider(registry: registry).fetchLyrics(context: context)
        #expect(text == "[00:01.25]Remote line")
        #expect(LyricsURLProtocol.requestedSongID == "song-42")
    }

    @Test("Remote cache keys separate songs with matching display metadata")
    func remoteCacheIdentity() {
        let directory = FileManager.default.temporaryDirectory
        let first = LyricsQueryContext(title: "Song", artist: "Artist", subsonicSongID: "one", sourceID: "server")
        let second = LyricsQueryContext(title: "Song", artist: "Artist", subsonicSongID: "two", sourceID: "server")
        #expect(CachedLyricsProvider.cacheFileURL(context: first, cacheDirectory: directory) != CachedLyricsProvider.cacheFileURL(context: second, cacheDirectory: directory))
    }
}

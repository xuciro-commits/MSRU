import Foundation
import MediaLibrary
import Testing
import MusicDomain
@testable import MSRU

@MainActor
@Suite("Subsonic prepared playback", .serialized)
struct SubsonicPreparedPlaybackTests {
    @Test("Playback request retains the selected Subsonic server")
    func requestCarriesServerIdentity() {
        let item = PlaybackItem.subsonic(
            serverID: LibrarySourceID("nas-two"),
            itemID: "song-7",
            title: "Track",
            artist: "Artist",
            streamURL: URL(string: "https://nas.example/rest/stream?id=song-7")
        )
        #expect(item.playbackRequest.subsonicServerID == "nas-two")
        #expect(item.playbackRequest.preparingPCM().prefersPreparedPCM)
    }

    @Test("A remote song without server identity or URL never picks an arbitrary NAS")
    func unidentifiedServerFails() async {
        let provider = RemoteSubsonicPlaybackProvider()
        do {
            _ = try await provider.resolve(PlaybackRequest(itemID: "song-7", source: .subsonic))
            Issue.record("Expected a missing server identity error")
        } catch {
            #expect(error.localizedDescription.contains("server identity"))
        }
    }

    @Test("Prepared remote audio is decoded and its temporary file is removed on close")
    func preparedAudioOwnsTemporaryFile() async throws {
        let source = try Fixtures.createDeterministicWAV(durationSeconds: 0.2)
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }
        let downloader = FixtureDownloader(source: source)
        let provider = RemoteSubsonicPlaybackProvider(downloadStore: downloader)
        let request = PlaybackRequest(
            itemID: "song-7",
            source: .subsonic,
            remoteURL: URL(string: "https://nas.example/rest/stream.view?id=song-7"),
            prefersPreparedPCM: true
        )
        let resource = try await provider.resolve(request)
        guard case .decodedPCM(let pcm) = resource.transport else {
            Issue.record("Expected decoded PCM after a successful download")
            return
        }
        #expect(pcm.format.sampleRate == 44_100)
        #expect(try await pcm.session.read(maxFrames: 256)?.frameCount == 256)
        let file = await downloader.lastFile
        #expect(file != nil)
        #expect(file.map { FileManager.default.fileExists(atPath: $0.path) } == true)
        await pcm.session.close()
        #expect(file.map { FileManager.default.fileExists(atPath: $0.path) } == false)
        #expect(await downloader.removalCount == 1)
    }

    @Test("Normal single-track streaming does not download the whole song")
    func regularStreamingKeepsAVPlayer() async throws {
        let source = try Fixtures.createDeterministicWAV(durationSeconds: 0.1)
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }
        let downloader = FixtureDownloader(source: source)
        let provider = RemoteSubsonicPlaybackProvider(downloadStore: downloader)
        let request = PlaybackRequest(
            itemID: "song-7",
            source: .subsonic,
            remoteURL: URL(string: "https://nas.example/rest/stream.view?id=song-7")
        )
        let resource = try await provider.resolve(request)
        guard case .avPlayerURL = resource.transport else {
            Issue.record("Expected ordinary remote streaming")
            return
        }
        #expect(await downloader.downloadCount == 0)
    }

    @Test("HTTP authentication failure never becomes a playable cache entry")
    func rejectedDownloadDoesNotCacheAudio() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [UnauthorizedAudioURLProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = RemoteAudioDownloadStore(session: session, directory: directory)
        do {
            _ = try await store.download(URL(string: "https://nas.example/rest/stream.view")!)
            Issue.record("Expected HTTP 401 to fail")
        } catch {
            #expect(error.localizedDescription.contains("credentials"))
        }
        #expect(!FileManager.default.fileExists(atPath: directory.path))
    }

    @Test("A cancelled NAS resolution cannot replace the new current track")
    func staleDownloadCannotReplacePlayback() async throws {
        let source = try Fixtures.createDeterministicWAV(durationSeconds: 0.3)
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }
        let downloader = StallingDownloader(source: source)
        let registry = ProviderRegistry()
        registry.register(RemoteSubsonicPlaybackProvider(downloadStore: downloader))
        registry.register(LocalPlaybackProvider())
        let playback = PlaybackController(providerKernel: PlaybackProviderKernel(registry: registry))
        let first = PlaybackItem.subsonic(
            itemID: "nas-a",
            title: "NAS A",
            artist: "Test",
            streamURL: URL(string: "https://nas.example/stream/a")
        )
        let second = PlaybackItem.subsonic(
            itemID: "nas-b",
            title: "NAS B",
            artist: "Test",
            streamURL: URL(string: "https://nas.example/stream/b")
        )
        let local = LocalTrack(fileURL: source, title: "Local", artist: "Test", album: "Album", duration: 0.3)
        playback.play(first, context: [first, second])
        await downloader.waitUntilStarted()
        playback.play(local, queue: [local])
        try await downloader.release()
        for _ in 0..<100 where await downloader.removalCount == 0 {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(playback.currentTrack?.id == local.id)
        #expect(playback.playbackErrorMessage == nil)
        #expect(await downloader.removalCount == 1)
        playback.stop()
    }

    @Test("A prepared NAS album advances through the PCM queue")
    func preparedNASAlbumAdvances() async throws {
        let source = try Fixtures.createDeterministicWAV(durationSeconds: 0.45)
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }
        let downloader = FixtureDownloader(source: source)
        let registry = ProviderRegistry()
        registry.register(RemoteSubsonicPlaybackProvider(downloadStore: downloader))
        registry.register(LocalPlaybackProvider())
        let playback = PlaybackController(providerKernel: PlaybackProviderKernel(registry: registry))
        let first = PlaybackItem.subsonic(
            itemID: "nas-a", title: "First", artist: "Test", album: "Album",
            duration: 0.45, streamURL: URL(string: "https://nas.example/stream/a")
        )
        let second = PlaybackItem.subsonic(
            itemID: "nas-b", title: "Second", artist: "Test", album: "Album",
            duration: 0.45, streamURL: URL(string: "https://nas.example/stream/b")
        )
        playback.play(first, context: [first, second])
        for _ in 0..<160 where playback.currentSubsonicSongID != "nas-b" {
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(playback.currentSubsonicSongID == "nas-b")
        #expect(playback.playbackQueue.history.count == 1)
        #expect(playback.playbackQueue.upcoming.isEmpty)
        #expect(playback.playbackErrorMessage == nil)
        #expect(await downloader.downloadCount == 2)
        let local = LocalTrack(fileURL: source, title: "Local", artist: "Test", album: "Album", duration: 0.45)
        playback.play(local, queue: [local])
        for _ in 0..<100 where await downloader.removalCount < 2 {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(await downloader.removalCount == 2)
        playback.stop()
    }

    @Test("A NAS response without a useful filename still decodes by file contents")
    func extensionlessResponseDecodes() async throws {
        let source = try Fixtures.createDeterministicWAV(durationSeconds: 0.1)
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }
        let downloader = FixtureDownloader(source: source, fileExtension: "audio")
        let provider = RemoteSubsonicPlaybackProvider(downloadStore: downloader)
        let resource = try await provider.resolve(PlaybackRequest(
            itemID: "nas-a", source: .subsonic,
            remoteURL: URL(string: "https://nas.example/rest/stream.view"),
            prefersPreparedPCM: true
        ))
        guard case .decodedPCM(let pcm) = resource.transport else {
            Issue.record("Expected content-based decoding")
            return
        }
        #expect(try await pcm.session.read(maxFrames: 128)?.frameCount == 128)
        await pcm.session.close()
        #expect(await downloader.removalCount == 1)
    }
}

private actor FixtureDownloader: RemoteAudioDownloading {
    let source: URL
    let fileExtension: String
    private(set) var lastFile: URL?
    private(set) var downloadCount = 0
    private(set) var removalCount = 0

    init(source: URL, fileExtension: String = "wav") {
        self.source = source
        self.fileExtension = fileExtension
    }

    func download(_ url: URL) throws -> URL {
        downloadCount += 1
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
        try FileManager.default.copyItem(at: source, to: output)
        lastFile = output
        return output
    }

    func remove(_ url: URL) {
        removalCount += 1
        try? FileManager.default.removeItem(at: url)
    }
}

private final class UnauthorizedAudioURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 401,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/plain"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private actor StallingDownloader: RemoteAudioDownloading {
    let source: URL
    private var pending: CheckedContinuation<URL, Error>?
    private var startedWaiters: [CheckedContinuation<Void, Never>] = []
    private(set) var removalCount = 0

    init(source: URL) { self.source = source }

    func download(_ url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            pending = continuation
            startedWaiters.forEach { $0.resume() }
            startedWaiters.removeAll()
        }
    }

    func waitUntilStarted() async {
        if pending != nil { return }
        await withCheckedContinuation { continuation in
            startedWaiters.append(continuation)
        }
    }

    func release() throws {
        guard let pending else { return }
        self.pending = nil
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        try FileManager.default.copyItem(at: source, to: file)
        pending.resume(returning: file)
    }

    func remove(_ url: URL) {
        removalCount += 1
        try? FileManager.default.removeItem(at: url)
    }
}

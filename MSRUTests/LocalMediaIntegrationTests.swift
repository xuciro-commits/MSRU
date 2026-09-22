import AVFoundation
import Foundation
import Testing
@testable import MSRU

@Suite("Audio Hardware Tests", .serialized)
enum AudioHardwareTestSuite {
    @Suite(.serialized)
    @MainActor
    struct LocalMediaIntegrationTests {
    @Test
    func importedWAVSurvivesReloadAndResolvesToPlayableAsset() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("Fixture.wav")
        try waveData().write(to: source)
        let directory = root.appendingPathComponent("Media")
        let ephemeralDB = try AppDatabase.makeEphemeral()
        let store = LocalLibraryStore(repository: FileLocalLibraryRepository(directory: directory), db: ephemeralDB)
        await store.importFiles([source])
        #expect(store.errorMessage == nil)
        let imported = try #require(store.tracks.first)
        #expect(imported.fileURL.deletingLastPathComponent().path == directory.resolvingSymlinksInPath().path)
        #expect(imported.title == "Fixture")
        #expect(abs(imported.duration - 0.2) < 0.01)
        #expect(try Data(contentsOf: imported.fileURL) == Data(contentsOf: source))

        let reopened = LocalLibraryStore(repository: FileLocalLibraryRepository(directory: directory), db: ephemeralDB)
        await reopened.loadIfNeeded()
        #expect(reopened.tracks.map(\.id) == [imported.id])
        let item = PlaybackItem(local: try #require(reopened.tracks.first))
        let resource = try await PlaybackProviderKernel.standard().resolver.resolve(item.playbackRequest)
        #expect(resource.providerID == .local)
        guard case .avPlayerURL(let url) = resource.transport else {
            Issue.record("Native local audio must resolve to an AVPlayer URL")
            return
        }
        let playable = try await AVURLAsset(url: url).load(.isPlayable)
        #expect(playable)
    }

    @Test
    func importingSameFilenamePreservesBothFiles() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("Repeated.wav")
        try waveData().write(to: source)
        let repository = FileLocalLibraryRepository(directory: root.appendingPathComponent("Media"))
        let first = try #require(await repository.importTrack(from: source))
        let second = try #require(await repository.importTrack(from: source))
        #expect(first.id != second.id)
        #expect(try Data(contentsOf: first.fileURL) == Data(contentsOf: second.fileURL))
        let reloaded = try await repository.loadTracks()
        #expect(Set(reloaded.map(\.id)) == Set([first.id, second.id]))
    }

    @Test
    func legacySavedPathAliasMatchesCanonicalFileAfterReload() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let media = root.appendingPathComponent("Media")
        try FileManager.default.createDirectory(at: media, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let original = media.appendingPathComponent("Song.wav")
        try waveData().write(to: original)
        let alias = root.appendingPathComponent("Alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: media)
        let legacy = LocalTrack(fileURL: alias.appendingPathComponent("Song.wav"), title: "Song",
            artist: "Unknown Artist", album: nil, duration: 0.2, artworkData: nil)
        let store = LibraryStore(repository: JSONLibraryRepository(fileURL: root.appendingPathComponent("Library.json")))
        let firstAdded = await store.add(local: legacy)
        #expect(firstAdded)
        let canonicalTracks = try await FileLocalLibraryRepository(directory: media).loadTracks()
        let canonical = try #require(canonicalTracks.first)
        #expect(store.contains(local: canonical))
        let duplicateAdded = await store.add(local: canonical)
        #expect(!duplicateAdded)
        #expect(store.tracks.count == 1)
    }

    @Test(arguments: [false, true])
    func queuedTerminalNotificationCannotChangeReplacementQueue(failure: Bool) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        var tracks: [LocalTrack] = []
        for name in ["First", "Second", "Third"] {
            let url = root.appendingPathComponent(name + ".wav")
            try waveData().write(to: url)
            tracks.append(LocalTrack(fileURL: url, title: name, artist: "Fixture",
                album: nil, duration: 0.2, artworkData: nil))
        }
        var players: [AVPlayer] = []
        let controller = PlaybackController(makePlayer: { url in
            // Keep the transport silent and stationary; post the end event explicitly.
            let player = AVPlayer(url: url)
            player.isMuted = true
            player.defaultRate = 0
            players.append(player)
            return player
        })
        defer { controller.stop() }
        let items = tracks.map { PlaybackItem(local: $0) }
        controller.play(items[0], context: items)
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while controller.isResolving && ContinuousClock.now < deadline { await Task.yield() }
        #expect(!controller.isResolving)
        let oldPlayer = try #require(players.first)
        let oldItem = try #require(oldPlayer.currentItem)
        NotificationCenter.default.post(name: failure ? AVPlayerItem.failedToPlayToEndTimeNotification
            : AVPlayerItem.didPlayToEndTimeNotification, object: oldItem)
        // The observer has queued a MainActor task, but cannot execute it until we yield.
        controller.play(items[1], context: items)
        while controller.isResolving && ContinuousClock.now < deadline { await Task.yield() }
        #expect(!controller.isResolving)
        #expect(controller.playbackErrorMessage == nil)
        #expect(controller.currentItem?.id == items[1].id)
        #expect(controller.playbackQueue.upcoming.map(\.item.id) == [items[2].id])
    }

    @Test
    func invalidMediaReportsTransportFailureAndCanRetryWithoutLosingQueue() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("Invalid.wav")
        try Data("This is not audio".utf8).write(to: url)
        let track = LocalTrack(fileURL: url, title: "Invalid", artist: "Fixture",
            album: nil, duration: 0.2, artworkData: nil)
        var players: [AVPlayer] = []
        let controller = PlaybackController(makePlayer: { url in
            let player = AVPlayer(url: url)
            player.isMuted = true
            players.append(player)
            return player
        })
        defer { controller.stop() }
        controller.play(track)
        let queueIDs = controller.playbackQueue.allItems.map(\.id)
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while controller.playbackErrorMessage == nil && ContinuousClock.now < deadline {
            await Task.yield()
        }
        let failedPlayer = try #require(players.first)
        #expect(failedPlayer.currentItem?.status == .failed)
        #expect(controller.playbackErrorMessage != nil)
        #expect(!controller.isPlaying)
        #expect(controller.currentResource == nil)
        #expect(!controller.isResolving)
        controller.retryLastFailedResolution()
        #expect(controller.playbackErrorMessage == nil)
        let retryDeadline = ContinuousClock.now.advanced(by: .seconds(5))
        while controller.isResolving && ContinuousClock.now < retryDeadline { await Task.yield() }
        #expect(players.count == 2)
        #expect(controller.playbackQueue.allItems.map(\.id) == queueIDs)
    }

    @Test
    func actualPlaybackAdvancesQueueAndStopsAtEnd() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let items = try ["First", "Second"].map { name in
            let url = root.appendingPathComponent(name + ".wav")
            try waveData().write(to: url)
            return PlaybackItem(local: LocalTrack(fileURL: url, title: name, artist: "Fixture",
                album: nil, duration: 0.2, artworkData: nil))
        }
        var players: [AVPlayer] = []
        let controller = PlaybackController(makePlayer: { url in
            let player = AVPlayer(url: url)
            player.isMuted = true
            players.append(player)
            return player
        })
        defer { controller.stop() }
        controller.play(items[0], context: items)
        let deadline = ContinuousClock.now.advanced(by: .seconds(10))
        while ContinuousClock.now < deadline {
            if controller.playbackErrorMessage != nil { break }
            if controller.currentItem?.id == items[1].id,
               !controller.isResolving, !controller.isPlaying,
               controller.currentTime > 0 { break }
            // Poll an actual media clock; elapsed time alone never satisfies the test.
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(controller.playbackErrorMessage == nil)
        #expect(players.count == 2)
        #expect(controller.currentItem?.id == items[1].id)
        #expect(controller.playbackQueue.history.map(\.item.id) == [items[0].id])
        #expect(controller.playbackQueue.upcoming.isEmpty)
        #expect(!controller.isPlaying)
        #expect(!controller.isResolving)
        #expect(abs(controller.currentTime - 0.2) < 0.02)
        // Actual AVPlayerItem clocks corroborate the controller's end state.
        for player in players {
            #expect(player.currentItem?.status == .readyToPlay)
            #expect(abs(player.currentTime().seconds - 0.2) < 0.02)
        }
    }

    @Test
    func volumeAndMuteStatePreservedAcrossTracksAndPlayers() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let items = try ["TrackA", "TrackB"].map { name in
            let url = root.appendingPathComponent(name + ".wav")
            try waveData().write(to: url)
            return PlaybackItem(local: LocalTrack(fileURL: url, title: name, artist: "Fixture",
                album: nil, duration: 0.2, artworkData: nil))
        }

        var players: [AVPlayer] = []
        let controller = PlaybackController(makePlayer: { url in
            let player = AVPlayer(url: url)
            players.append(player)
            return player
        })
        defer { controller.stop() }

        // Start first track
        controller.play(items[0], context: items)
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while controller.isResolving && ContinuousClock.now < deadline { await Task.yield() }
        #expect(!controller.isResolving)

        let firstPlayer = try #require(players.first)
        #expect(controller.volume == 1.0)
        #expect(!controller.isMuted)
        #expect(firstPlayer.volume == 1.0)
        #expect(!firstPlayer.isMuted)

        // Adjust volume and toggle mute
        controller.setVolume(0.45)
        #expect(abs(controller.volume - 0.45) < 0.001)
        #expect(abs(firstPlayer.volume - 0.45) < 0.001)

        controller.toggleMute()
        #expect(controller.isMuted)
        #expect(firstPlayer.isMuted)
        #expect(firstPlayer.volume == 0.0)

        // Transition to next track: new player MUST inherit volume & mute state
        controller.next()
        let nextDeadline = ContinuousClock.now.advanced(by: .seconds(5))
        while controller.isResolving && ContinuousClock.now < nextDeadline { await Task.yield() }
        #expect(!controller.isResolving)
        #expect(players.count == 2)

        let secondPlayer = players[1]
        #expect(controller.isMuted)
        #expect(secondPlayer.isMuted)
        #expect(secondPlayer.volume == 0.0)
        #expect(abs(controller.volume - 0.45) < 0.001)

        // Adjusting volume while muted automatically un-mutes
        controller.setVolume(0.8)
        #expect(!controller.isMuted)
        #expect(!secondPlayer.isMuted)
        #expect(abs(secondPlayer.volume - 0.8) < 0.001)
    }

    @Test
    func mixedQueueAdvancesFromLocalWAVToRadioLiveStream() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let localURL = root.appendingPathComponent("Local.wav")
        try waveData().write(to: localURL)
        let localItem = PlaybackItem(local: LocalTrack(fileURL: localURL, title: "Local Song", artist: "Artist",
            album: nil, duration: 0.2, artworkData: nil))

        let radioStation = RadioStation(
            id: "classic-fm-test",
            name: "Classic FM Test",
            description: "Test radio description",
            genre: .classical,
            streamURL: URL(string: "https://media-ssl.musicradio.com/ClassicFM")!,
            country: "UK",
            language: "English",
            codec: "AAC",
            bitrateKbps: 128
        )
        let radioItem = PlaybackItem(radio: radioStation)

        var players: [AVPlayer] = []
        let controller = PlaybackController(makePlayer: { url in
            let player = AVPlayer(url: url)
            player.isMuted = true
            players.append(player)
            return player
        })
        defer { controller.stop() }

        // Start mixed queue: [localItem, radioItem]
        controller.play(localItem, context: [localItem, radioItem])
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while controller.isResolving && ContinuousClock.now < deadline { await Task.yield() }
        #expect(!controller.isResolving)
        #expect(controller.currentItem?.id == localItem.id)
        #expect(controller.unifiedProviderLabel == "LOCAL")
        #expect(controller.duration > 0)

        // Advance to radio stream
        controller.next()
        let radioDeadline = ContinuousClock.now.advanced(by: .seconds(5))
        while controller.isResolving && ContinuousClock.now < radioDeadline { await Task.yield() }
        #expect(!controller.isResolving)
        #expect(controller.currentItem?.id == radioItem.id)
        #expect(controller.radioCurrentStation?.name == "Classic FM Test")
        #expect(controller.unifiedProviderLabel == "LIVE RADIO")
        #expect(controller.duration == 0)
        #expect(controller.playbackQueue.history.map(\.item.id) == [localItem.id])
        #expect(players.count == 2)
    }

    @Test
    func scrubbingPreviewAndSeekBehavior() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let localURL = root.appendingPathComponent("SeekTest.wav")
        try waveData().write(to: localURL)
        let item = PlaybackItem(local: LocalTrack(fileURL: localURL, title: "Seek", artist: "Artist",
            album: nil, duration: 0.2, artworkData: nil))

        var players: [AVPlayer] = []
        let controller = PlaybackController(makePlayer: { url in
            let player = AVPlayer(url: url)
            player.isMuted = true
            players.append(player)
            return player
        })
        defer { controller.stop() }

        controller.play(item)
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while controller.isResolving && ContinuousClock.now < deadline { await Task.yield() }
        #expect(!controller.isResolving)

        // Seek to 50%
        controller.seek(toProgress: 0.5)
        #expect(abs(controller.currentTime - 0.1) < 0.01)

        // Clamping check
        controller.seek(toProgress: -0.5)
        #expect(controller.currentTime == 0.0)

        controller.seek(toProgress: 1.5)
        #expect(abs(controller.currentTime - 0.2) < 0.01)
    }

    /// 0.2 seconds of real PCM WAV data; tests decode it without producing sound.
    private func waveData() -> Data {
        let sampleCount: UInt32 = 8_820
        let byteCount = sampleCount * 2
        var data = Data()
        func text(_ value: String) { data.append(contentsOf: value.utf8) }
        func integer<T: FixedWidthInteger>(_ value: T) {
            var littleEndian = value.littleEndian
            withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
        }
        text("RIFF"); integer(UInt32(36) + byteCount); text("WAVE")
        text("fmt "); integer(UInt32(16)); integer(UInt16(1)); integer(UInt16(1))
        integer(UInt32(44_100)); integer(UInt32(88_200)); integer(UInt16(2)); integer(UInt16(16))
        text("data"); integer(byteCount)
        data.append(Data(repeating: 0, count: Int(byteCount)))
        return data
    }
}
}

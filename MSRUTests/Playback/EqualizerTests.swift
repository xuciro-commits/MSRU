import Foundation
import Testing
@testable import MSRU

@MainActor
@Suite("Ten-band equalizer", .serialized)
struct EqualizerTests {
    @Test("Preset, bypass, and custom edits survive store reconstruction")
    func persistenceAndPresetEditing() {
        let suite = "msru-eq-tests-\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }

        let first = EqualizerStore(preferences: preferences)
        #expect(first.state.gains.count == 10)
        #expect(!first.state.isEnabled)
        first.applyPreset("bass")
        first.setEnabled(true)
        #expect(first.state.gains[0] == 6)
        #expect(first.state.selectedPresetID == "bass")
        first.setGain(8.5, band: 2)
        #expect(first.state.selectedPresetID == nil)
        let custom = first.saveCurrentPreset(named: "  My DAC  ")!

        let restored = EqualizerStore(preferences: preferences)
        #expect(restored.state.isEnabled)
        #expect(restored.state.selectedPresetID == custom.id)
        #expect(restored.state.gains[2] == 8.5)
        #expect(restored.state.customPresets.first?.name == "My DAC")
        restored.applyPreset("flat")
        #expect(restored.state.gains.allSatisfy { $0 == 0 })
        restored.applyPreset(custom.id)
        #expect(restored.state.gains[2] == 8.5)
        restored.deletePreset(custom.id)
        #expect(restored.state.selectedPresetID == nil)
        #expect(restored.state.customPresets.isEmpty)
    }

    @Test("Band limits and pre-EQ headroom protect boosted output")
    func gainAndBypass() async throws {
        let suite = "msru-eq-tests-\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        let store = EqualizerStore(preferences: preferences)
        store.setGain(30, band: 0)
        store.setGain(-30, band: 1)
        store.setGain(.nan, band: 2)
        #expect(store.state.gains[0] == 12)
        #expect(store.state.gains[1] == -12)
        #expect(store.state.gains[2] == 0)
        #expect(store.state.headroomMultiplier == 1)
        store.setEnabled(true)
        #expect(store.state.headroomDecibels == 12)

        let url = try Fixtures.createDeterministicWAV(durationSeconds: 0.2)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let decoded = try await AppleAudioFileDecoder().open(url)
        let engine = try PCMPlaybackEngine(
            resource: PCMPlaybackResource(format: decoded.format, session: decoded.session),
            equalizer: store.state
        )
        engine.volume = 0.8
        let outputRate = engine.outputSampleRate
        #expect(!engine.equalizerIsBypassed)
        #expect(engine.equalizerBandGains[0] == 12)
        #expect(engine.renderedVolume < 0.21)
        #expect(engine.outputSampleRate == outputRate)

        store.setEnabled(false)
        engine.applyEqualizer(store.state)
        #expect(engine.equalizerIsBypassed)
        #expect(engine.equalizerBandGains[0] == 12)
        #expect(abs(engine.renderedVolume - 0.8) < 0.001)
        await engine.close()
    }

    @Test("A prepared next track keeps the same equalizer and gain compensation")
    func survivesGaplessTransition() async throws {
        let firstURL = try Fixtures.createDeterministicWAV(durationSeconds: 0.3)
        let secondURL = try Fixtures.createDeterministicWAV(durationSeconds: 0.3)
        defer {
            try? FileManager.default.removeItem(at: firstURL.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: secondURL.deletingLastPathComponent())
        }
        let decoder = AppleAudioFileDecoder()
        let first = try await decoder.open(firstURL)
        let second = try await decoder.open(secondURL)
        var eq = EqualizerState()
        eq.isEnabled = true
        eq.gains[5] = 6
        let engine = try PCMPlaybackEngine(
            resource: PCMPlaybackResource(format: first.format, session: first.session),
            equalizer: eq
        )
        engine.volume = 1
        let resource = PlaybackResource(
            providerID: .local,
            transport: .decodedPCM(PCMPlaybackResource(format: second.format, session: second.session)),
            duration: second.format.duration
        )
        let nextID = UUID()
        var advanced = false
        engine.onAdvanced = { id, _ in
            #expect(id == nextID)
            advanced = true
        }
        engine.prepareNext(queueID: nextID, resource: resource)
        engine.play()
        for _ in 0..<80 where !advanced {
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(advanced)
        #expect(!engine.equalizerIsBypassed)
        #expect(engine.equalizerBandGains[5] == 6)
        #expect(engine.renderedVolume < 0.51)
        await engine.close()
    }
}

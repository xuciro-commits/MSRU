import Foundation
import Observation
import MusicDomain
import MusicLibrary

public struct EqualizerPreset: Codable, Equatable, Identifiable {
    public let id: String
    public var name: String
    public var gains: [Float]

    public static let builtIn: [EqualizerPreset] = [
        .init(id: "flat", name: "Flat", gains: Array(repeating: 0, count: 10)),
        .init(id: "bass", name: "Bass Boost", gains: [6, 5, 4, 2, 0, 0, 0, 0, 0, 0]),
        .init(id: "vocal", name: "Vocal", gains: [-2, -1, 0, 1, 2, 3, 3, 1, 0, -1]),
        .init(id: "treble", name: "Treble Boost", gains: [0, 0, 0, 0, 0, 1, 2, 4, 5, 6]),
        .init(id: "warm", name: "Warm", gains: [3, 3, 2, 1, 0, -1, -1, 0, 1, 1])
    ]

    nonisolated public init(
        id: String,
        name: String,
        gains: [Float]
    ) {
        self.id = id
        self.name = name
        self.gains = gains
    }
}

public struct EqualizerState: Codable, Equatable {
    public static let frequencies: [Float] = [31, 62, 125, 250, 500, 1_000, 2_000, 4_000, 8_000, 16_000]
    public static let gainRange: ClosedRange<Float> = -12...12

    public var isEnabled = false
    public var gains = Array(repeating: Float.zero, count: 10)
    public var selectedPresetID: String? = "flat"
    public var customPresets: [EqualizerPreset] = []

    public mutating func sanitize() {
        gains = Self.sanitize(gains)
        customPresets = customPresets.compactMap { preset in
            let name = preset.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            return EqualizerPreset(id: preset.id, name: name, gains: Self.sanitize(preset.gains))
        }
        if let selectedPresetID,
           !EqualizerPreset.builtIn.contains(where: { $0.id == selectedPresetID }),
           !customPresets.contains(where: { $0.id == selectedPresetID }) {
            self.selectedPresetID = nil
        }
    }

    public static func sanitize(_ values: [Float]) -> [Float] {
        (0..<frequencies.count).map { index in
            guard index < values.count, values[index].isFinite else { return 0 }
            return min(max(values[index], gainRange.lowerBound), gainRange.upperBound)
        }
    }

    nonisolated public init() {}
}

@MainActor @Observable
public final class EqualizerStore {
    private let preferences: UserDefaults
    private let key = "playback.equalizer.state.v1"
    public private(set) var state: EqualizerState

    public init(preferences: UserDefaults = .standard) {
        self.preferences = preferences
        if let data = preferences.data(forKey: key),
           var saved = try? JSONDecoder().decode(EqualizerState.self, from: data) {
            saved.sanitize()
            state = saved
        } else {
            state = EqualizerState()
        }
    }

    public var presets: [EqualizerPreset] { EqualizerPreset.builtIn + state.customPresets }

    public func setEnabled(_ enabled: Bool) {
        state.isEnabled = enabled
        persist()
    }

    public func setGain(_ gain: Float, band: Int) {
        guard state.gains.indices.contains(band) else { return }
        state.gains[band] = gain.isFinite
            ? min(max(gain, EqualizerState.gainRange.lowerBound), EqualizerState.gainRange.upperBound) : 0
        state.selectedPresetID = nil
        persist()
    }

    public func applyPreset(_ id: String) {
        guard let preset = presets.first(where: { $0.id == id }) else { return }
        state.gains = EqualizerState.sanitize(preset.gains)
        state.selectedPresetID = id
        persist()
    }

    @discardableResult
    public func saveCurrentPreset(named rawName: String) -> EqualizerPreset? {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        let preset = EqualizerPreset(id: UUID().uuidString, name: name, gains: state.gains)
        state.customPresets.append(preset)
        state.selectedPresetID = preset.id
        persist()
        return preset
    }

    public func deletePreset(_ id: String) {
        guard state.customPresets.contains(where: { $0.id == id }) else { return }
        state.customPresets.removeAll { $0.id == id }
        if state.selectedPresetID == id { state.selectedPresetID = nil }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        preferences.set(data, forKey: key)
    }
}

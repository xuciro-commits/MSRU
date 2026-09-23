import Foundation
import Observation

struct EqualizerPreset: Codable, Equatable, Identifiable {
    let id: String
    var name: String
    var gains: [Float]

    static let builtIn: [EqualizerPreset] = [
        .init(id: "flat", name: "Flat", gains: Array(repeating: 0, count: 10)),
        .init(id: "bass", name: "Bass Boost", gains: [6, 5, 4, 2, 0, 0, 0, 0, 0, 0]),
        .init(id: "vocal", name: "Vocal", gains: [-2, -1, 0, 1, 2, 3, 3, 1, 0, -1]),
        .init(id: "treble", name: "Treble Boost", gains: [0, 0, 0, 0, 0, 1, 2, 4, 5, 6]),
        .init(id: "warm", name: "Warm", gains: [3, 3, 2, 1, 0, -1, -1, 0, 1, 1])
    ]
}

struct EqualizerState: Codable, Equatable {
    static let frequencies: [Float] = [31, 62, 125, 250, 500, 1_000, 2_000, 4_000, 8_000, 16_000]
    static let gainRange: ClosedRange<Float> = -12...12

    var isEnabled = false
    var gains = Array(repeating: Float.zero, count: 10)
    var selectedPresetID: String? = "flat"
    var customPresets: [EqualizerPreset] = []

    var headroomDecibels: Float {
        guard isEnabled else { return 0 }
        return gains.reduce(0) { $0 + max(0, $1) }
    }

    var headroomMultiplier: Float {
        Float(pow(10, Double(-headroomDecibels) / 20))
    }

    mutating func sanitize() {
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

    static func sanitize(_ values: [Float]) -> [Float] {
        (0..<frequencies.count).map { index in
            guard index < values.count, values[index].isFinite else { return 0 }
            return min(max(values[index], gainRange.lowerBound), gainRange.upperBound)
        }
    }
}

@MainActor @Observable
final class EqualizerStore {
    private let preferences: UserDefaults
    private let key = "playback.equalizer.state.v1"
    private(set) var state: EqualizerState

    init(preferences: UserDefaults = .standard) {
        self.preferences = preferences
        if let data = preferences.data(forKey: key),
           var saved = try? JSONDecoder().decode(EqualizerState.self, from: data) {
            saved.sanitize()
            state = saved
        } else {
            state = EqualizerState()
        }
    }

    var presets: [EqualizerPreset] { EqualizerPreset.builtIn + state.customPresets }

    func setEnabled(_ enabled: Bool) {
        state.isEnabled = enabled
        persist()
    }

    func setGain(_ gain: Float, band: Int) {
        guard state.gains.indices.contains(band) else { return }
        state.gains[band] = gain.isFinite
            ? min(max(gain, EqualizerState.gainRange.lowerBound), EqualizerState.gainRange.upperBound) : 0
        state.selectedPresetID = nil
        persist()
    }

    func applyPreset(_ id: String) {
        guard let preset = presets.first(where: { $0.id == id }) else { return }
        state.gains = EqualizerState.sanitize(preset.gains)
        state.selectedPresetID = id
        persist()
    }

    @discardableResult
    func saveCurrentPreset(named rawName: String) -> EqualizerPreset? {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        let preset = EqualizerPreset(id: UUID().uuidString, name: name, gains: state.gains)
        state.customPresets.append(preset)
        state.selectedPresetID = preset.id
        persist()
        return preset
    }

    func deletePreset(_ id: String) {
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

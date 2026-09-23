import Foundation
import Observation
import MusicDomain
import MusicLibrary

public enum ReplayGainMode: String, CaseIterable, Codable, Sendable {
    case off
    case track
    case album
}

public nonisolated enum ReplayGainPolicy {
    public static let targetLUFS = -23.0
    public static let ceilingDBFS = -1.0

    /// Sample-peak ceiling with an additional allowance for positive EQ bands.
    /// This is a conservative prevention strategy, not a true-peak guarantee.
    public static func gainDB(for measurement: R128Measurement?, eqGains: [Float] = []) -> Float {
        guard let measurement, measurement.integratedLUFS.isFinite,
              measurement.samplePeak.isFinite, measurement.samplePeak > 0 else { return 0 }
        let requested = targetLUFS - measurement.integratedLUFS
        let peakDBFS = 20 * log10(measurement.samplePeak)
        let eqAllowance = eqGains.reduce(0.0) { $0 + max(0, Double($1)) }
        let safe = ceilingDBFS - peakDBFS - eqAllowance
        return Float(max(-30, min(requested, safe, 18)))
    }
}

@MainActor @Observable
public final class ReplayGainSettings {
    private let preferences: UserDefaults
    private let key = "playback.replayGain.mode.v1"
    public private(set) var mode: ReplayGainMode

    public init(preferences: UserDefaults = .standard) {
        self.preferences = preferences
        mode = ReplayGainMode(rawValue: preferences.string(forKey: key) ?? "") ?? .off
    }

    public func setMode(_ mode: ReplayGainMode) {
        self.mode = mode
        preferences.set(mode.rawValue, forKey: key)
    }
}

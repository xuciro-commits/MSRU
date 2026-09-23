import Foundation
import MusicDomain
import MusicLibrary

/// Streaming BS.1770 K-weighted integrated loudness for mono and stereo PCM.
/// Uses EBU Tech 3341's 400 ms blocks, 75% overlap, -70 LUFS absolute gate,
/// then a gate 10 LU below the absolute-gated mean. Peak is a sample peak.
public nonisolated struct R128Measurement: Sendable, Equatable {
    public let integratedLUFS: Double
    public let samplePeak: Double
    public let duration: TimeInterval

    public init(
        integratedLUFS: Double,
        samplePeak: Double,
        duration: TimeInterval
    ) {
        self.integratedLUFS = integratedLUFS
        self.samplePeak = samplePeak
        self.duration = duration
    }
}

public nonisolated struct R128Meter {
    private struct Biquad {
        public let b0: Double
        public let b1: Double
        public let b2: Double
        public let a1: Double
        public let a2: Double
        public var x1 = 0.0
        public var x2 = 0.0
        public var y1 = 0.0
        public var y2 = 0.0

        public mutating func process(_ x: Double) -> Double {
            let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            x2 = x1
            x1 = x
            y2 = y1
            y1 = y
            return y
        }
    }

    private let sampleRate: Double
    private let channels: Int
    private let windowFrames: Int
    private let hopFrames: Int
    private var shelves: [Biquad]
    private var highPasses: [Biquad]
    private var window: [Double]
    private var windowIndex = 0
    private var windowSum = 0.0
    private var frameCount = 0
    private var blockEnergies: [Double] = []
    private var samplePeak = 0.0

    public init?(sampleRate: Double, channels: Int) {
        guard sampleRate >= 8_000, sampleRate.isFinite, (1...2).contains(channels) else { return nil }
        self.sampleRate = sampleRate
        self.channels = channels
        windowFrames = max(1, Int((sampleRate * 0.4).rounded()))
        hopFrames = max(1, Int((sampleRate * 0.1).rounded()))
        window = Array(repeating: 0, count: windowFrames)

        // Bilinear-transform coefficients used by libebur128 for arbitrary sample rates.
        let shelfK = tan(.pi * 1681.974450955533 / sampleRate)
        let shelfQ = 0.7071752369554196
        let high = pow(10.0, 3.999843853973347 / 20.0)
        let middle = pow(high, 0.4996667741545416)
        let shelfDenominator = 1 + shelfK / shelfQ + shelfK * shelfK
        let shelf = Biquad(
            b0: (high + middle * shelfK / shelfQ + shelfK * shelfK) / shelfDenominator,
            b1: 2 * (shelfK * shelfK - high) / shelfDenominator,
            b2: (high - middle * shelfK / shelfQ + shelfK * shelfK) / shelfDenominator,
            a1: 2 * (shelfK * shelfK - 1) / shelfDenominator,
            a2: (1 - shelfK / shelfQ + shelfK * shelfK) / shelfDenominator
        )
        let highPassK = tan(.pi * 38.13547087602444 / sampleRate)
        let highPassQ = 0.5003270373238773
        let highPassDenominator = 1 + highPassK / highPassQ + highPassK * highPassK
        let highPass = Biquad(
            b0: 1, b1: -2, b2: 1,
            a1: 2 * (highPassK * highPassK - 1) / highPassDenominator,
            a2: (1 - highPassK / highPassQ + highPassK * highPassK) / highPassDenominator
        )
        shelves = Array(repeating: shelf, count: channels)
        highPasses = Array(repeating: highPass, count: channels)
    }

    public mutating func append(_ block: PCMFrameBlock) {
        guard block.channels.count == channels,
              block.channels.allSatisfy({ $0.count >= block.frameCount }) else { return }
        for frame in 0..<block.frameCount {
            var energy = 0.0
            for channel in 0..<channels {
                let sample = Double(block.channels[channel][frame])
                guard sample.isFinite else { continue }
                samplePeak = max(samplePeak, abs(sample))
                let filtered = highPasses[channel].process(shelves[channel].process(sample))
                energy += filtered * filtered
            }
            windowSum += energy - window[windowIndex]
            window[windowIndex] = energy
            windowIndex = (windowIndex + 1) % windowFrames
            frameCount += 1
            if frameCount >= windowFrames && (frameCount - windowFrames) % hopFrames == 0 {
                blockEnergies.append(max(0, windowSum) / Double(windowFrames))
            }
        }
    }

    public func measurement() -> R128Measurement? {
        Self.measure(energies: blockEnergies, samplePeak: samplePeak, duration: Double(frameCount) / sampleRate)
    }

    public var gatingBlockEnergies: [Double] { blockEnergies }
    public var peak: Double { samplePeak }
    public var duration: TimeInterval { Double(frameCount) / sampleRate }

    public static func measure(energies: [Double], samplePeak: Double, duration: TimeInterval) -> R128Measurement? {
        let absoluteThreshold = pow(10.0, (-70 + 0.691) / 10.0)
        let aboveAbsolute = energies.filter { $0 >= absoluteThreshold }
        guard !aboveAbsolute.isEmpty else { return nil }
        let relativeThreshold = aboveAbsolute.reduce(0, +) / Double(aboveAbsolute.count) * 0.1
        let selected = aboveAbsolute.filter { $0 >= relativeThreshold }
        guard !selected.isEmpty else { return nil }
        let energy = selected.reduce(0, +) / Double(selected.count)
        return R128Measurement(
            integratedLUFS: -0.691 + 10 * log10(energy),
            samplePeak: samplePeak,
            duration: duration
        )
    }
}

//
//  VisualizerEngine.swift
//  MSRU
//
//  Harmonic physics and frequency spectrum synthesis for audio visualization.
//

import Foundation
import CoreGraphics

public struct VisualizerEngine: Sendable {

    /// Computes normalized frequency amplitude [0.0...1.0] for a given frequency band.
    ///
    /// - Parameters:
    ///   - bandIndex: Zero-indexed position along the frequency spectrum.
    ///   - totalBands: Total number of discrete frequency bands.
    ///   - time: Elapsed reference timestamp in seconds.
    ///   - isPlaying: Whether audio is actively playing.
    ///   - volume: Output volume multiplier [0.0...1.0].
    ///   - sensitivity: User sensitivity multiplier [0.5...2.0].
    public static func computeBand(
        index: Int,
        totalBands: Int,
        time: Double,
        isPlaying: Bool,
        volume: Float = 1.0,
        sensitivity: Double = 1.0
    ) -> Double {
        let count = max(1, totalBands)
        let normalizedPos = Double(index) / Double(max(1, count - 1))

        if !isPlaying {
            // Meditative breathing idle pulse: soft, organic, living rhythm
            let breath = (sin(time * 1.2 + normalizedPos * 2.0) + 1.0) * 0.5
            let envelope = sin(normalizedPos * .pi) * 0.6 + 0.4
            return max(0.04, breath * 0.12 * envelope)
        }

        // Multi-frequency harmonic resonance
        // Bass range (0.0 ... 0.25): strong dynamic punch
        let bassBeat = pow(max(0.0, sin(time * 4.2)), 3.0) * 0.8
        let subBass = (sin(time * 2.1 - normalizedPos * 3.0) + 1.0) * 0.35

        // Mid-range (0.25 ... 0.70): vocal & melodic fluidity
        let midWave1 = sin(time * 6.5 + normalizedPos * 8.0) * 0.35
        let midWave2 = cos(time * 9.2 - normalizedPos * 6.5) * 0.25

        // Treble & Air (0.70 ... 1.0): crisp transient sparkle & fast flutter
        let trebleFlutter = sin(time * 14.5 + Double(index) * 1.8) * 0.22
        let airNoise = cos(time * 22.0 - Double(index) * 2.4) * 0.15

        // Spectral contour curve: full body in bass, natural elevation in mids, airy roll-off
        let spectralContour: Double
        if normalizedPos < 0.28 {
            // Bass zone
            spectralContour = 0.95 - normalizedPos * 0.4
        } else if normalizedPos < 0.72 {
            // Mid zone
            spectralContour = 0.85 + sin((normalizedPos - 0.28) / 0.44 * .pi) * 0.2
        } else {
            // High / Air zone
            spectralContour = 0.75 - (normalizedPos - 0.72) * 0.6
        }

        // Sum components with band weighting
        let rawEnergy = (bassBeat * (1.0 - normalizedPos * 0.8)
                         + subBass * (1.0 - normalizedPos * 0.6)
                         + (midWave1 + midWave2 + 0.6) * 0.5
                         + (trebleFlutter + airNoise + 0.4) * 0.4)
            * spectralContour

        let effectiveVol = Double(max(0.2, min(1.0, volume)))
        let energy = rawEnergy * effectiveVol * sensitivity

        return max(0.04, min(1.0, energy))
    }

    /// Computes a continuous smooth wave height at a normalized horizontal position x in [0.0...1.0].
    public static func computeWaveHeight(
        x: Double,
        time: Double,
        layerIndex: Int,
        isPlaying: Bool,
        volume: Float = 1.0,
        sensitivity: Double = 1.0
    ) -> Double {
        if !isPlaying {
            let slowPhase = time * 0.8 + Double(layerIndex) * 1.2
            let idleWave = sin(x * 3.5 + slowPhase) * 0.08 + cos(x * 2.0 - slowPhase * 0.5) * 0.05
            return 0.15 + idleWave
        }

        let speed = 2.4 + Double(layerIndex) * 0.9
        let phase = time * speed + Double(layerIndex) * 1.8

        // Combined fluid harmonics
        let w1 = sin(x * 4.2 + phase) * 0.35
        let w2 = cos(x * 7.5 - phase * 1.3) * 0.22
        let w3 = sin(x * 12.0 + phase * 2.1) * 0.12
        let w4 = cos(x * 2.5 + time * 1.6) * 0.18

        let composite = (w1 + w2 + w3 + w4 + 0.85) * 0.5
        let effectiveVol = Double(max(0.25, min(1.0, volume)))
        let scaled = composite * effectiveVol * sensitivity

        return max(0.06, min(0.96, scaled))
    }

    /// Computes a radial spike length at angle theta [0...2*PI].
    public static func computeRadialSpike(
        angle: Double,
        time: Double,
        isPlaying: Bool,
        volume: Float = 1.0,
        sensitivity: Double = 1.0
    ) -> Double {
        if !isPlaying {
            let breath = (sin(time * 1.5 + angle * 2.0) + 1.0) * 0.5
            return 0.1 + breath * 0.06
        }

        let oct1 = sin(angle * 6.0 + time * 4.5) * 0.3
        let oct2 = cos(angle * 12.0 - time * 6.8) * 0.25
        let oct3 = sin(angle * 24.0 + time * 11.2) * 0.15
        let pulse = pow(max(0.0, sin(time * 3.8)), 4.0) * 0.35

        let composite = (oct1 + oct2 + oct3 + pulse + 0.8) * 0.5
        let effectiveVol = Double(max(0.25, min(1.0, volume)))

        return max(0.06, min(1.0, composite * effectiveVol * sensitivity))
    }
}

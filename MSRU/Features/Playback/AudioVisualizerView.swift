//
//  AudioVisualizerView.swift
//  MSRU
//

import SwiftUI

/// Dynamic multi-bar audio waveform visualizer.
///
/// Responsive to playback state and volume level, smoothly transitioning
/// between rhythmic frequency bar heights when playing and resting baseline when paused.
struct AudioVisualizerView: View {
    let isPlaying: Bool
    var volume: Float = 1.0
    var barCount: Int = 7
    var barWidth: CGFloat = 3.5
    var spacing: CGFloat = 3
    var maxHeight: CGFloat = 28
    var minHeight: CGFloat = 4
    var tintColor: Color = .accentColor

    @State private var phase: Double = 0.0

    var body: some View {
        HStack(alignment: .center, spacing: spacing) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(tintColor.opacity(barOpacity(for: index)))
                    .frame(
                        width: barWidth,
                        height: barHeight(for: index)
                    )
            }
        }
        .frame(height: maxHeight)
        .onAppear {
            if isPlaying {
                startAnimation()
            }
        }
        .onChange(of: isPlaying) { _, playing in
            if playing {
                startAnimation()
            } else {
                withAnimation(.easeOut(duration: 0.35)) {
                    phase = 0.0
                }
            }
        }
    }

    private func startAnimation() {
        withAnimation(
            .easeInOut(duration: 0.65)
            .repeatForever(autoreverses: true)
        ) {
            phase = 1.0
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        guard isPlaying else { return minHeight }

        // Natural frequency bell curve distribution
        let normalizedIndex = Double(index) / Double(max(1, barCount - 1))
        let centerWeight = 1.0 - abs(normalizedIndex - 0.5) * 1.2
        let harmonicFactor = sin((Double(index) * 0.9) + (phase * .pi))

        let dynamicScale = (centerWeight * 0.55 + 0.45) * (0.35 + 0.65 * abs(harmonicFactor))
        let effectiveVolume = CGFloat(max(0.15, min(1.0, volume)))
        let targetHeight = minHeight + (maxHeight - minHeight) * CGFloat(dynamicScale) * effectiveVolume

        return max(minHeight, min(maxHeight, targetHeight))
    }

    private func barOpacity(for index: Int) -> Double {
        if !isPlaying {
            return 0.4
        }
        let normalized = Double(index) / Double(max(1, barCount - 1))
        return 0.65 + 0.35 * (1.0 - abs(normalized - 0.5))
    }
}

#Preview("Audio Visualizer - Playing") {
    VStack(spacing: 24) {
        AudioVisualizerView(isPlaying: true, volume: 0.9)
        AudioVisualizerView(isPlaying: false, volume: 0.9)
        AudioVisualizerView(isPlaying: true, volume: 0.5, barCount: 11, barWidth: 4, maxHeight: 36, tintColor: .purple)
    }
    .padding(40)
    .background(Color.black)
}

//
//  StudioBarsVisualizerView.swift
//  MSRU
//
//  Hardware rack-mount studio equalizer visualizer with segmented LEDs, tri-zone colors, and peak-hold indicators.
//

import SwiftUI

public struct StudioBarsVisualizerView: View {
    public let isPlaying: Bool
    public var volume: Float = 1.0
    public var sensitivity: Double = 1.0
    public var theme: VisualizerColorTheme = .aurora
    public var barCount: Int = 24

    // State storing peak heights and decay timers for each bar
    @State private var peakLevels: [Double] = []
    @State private var peakHoldTimers: [Double] = []

    public init(
        isPlaying: Bool,
        volume: Float = 1.0,
        sensitivity: Double = 1.0,
        theme: VisualizerColorTheme = .aurora,
        barCount: Int = 24
    ) {
        self.isPlaying = isPlaying
        self.volume = volume
        self.sensitivity = sensitivity
        self.theme = theme
        self.barCount = barCount
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: isPlaying ? 1.0 / 60.0 : 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                drawBars(context: &context, size: size, time: time)
            }
        }
        .onAppear {
            if peakLevels.count != barCount {
                peakLevels = Array(repeating: 0.05, count: barCount)
                peakHoldTimers = Array(repeating: 0.0, count: barCount)
            }
        }
    }

    private func drawBars(context: inout GraphicsContext, size: CGSize, time: Double) {
        guard size.width > 0 && size.height > 0 else { return }

        let count = barCount
        let spacing: CGFloat = 3.5
        let totalSpacing = spacing * CGFloat(count - 1)
        let barWidth = max(3.0, (size.width - totalSpacing) / CGFloat(count))
        let maxHeight = size.height * 0.88

        let segmentHeight: CGFloat = 3.5
        let segmentGap: CGFloat = 1.5
        let totalSegmentStep = segmentHeight + segmentGap
        let maxSegments = max(1, Int(maxHeight / totalSegmentStep))

        for i in 0..<count {
            let energy = VisualizerEngine.computeBand(
                index: i,
                totalBands: count,
                time: time,
                isPlaying: isPlaying,
                volume: volume,
                sensitivity: sensitivity
            )

            let x = CGFloat(i) * (barWidth + spacing)
            let activeSegments = Int(Double(maxSegments) * energy)

            // Draw stacked LED segments
            for s in 0..<maxSegments {
                let segY = size.height - CGFloat(s + 1) * totalSegmentStep
                let segRect = CGRect(x: x, y: segY, width: barWidth, height: segmentHeight)
                let segPath = Path(roundedRect: segRect, cornerRadius: 1.0)

                let segNorm = Double(s) / Double(maxSegments)

                let segColor: Color
                if segNorm < 0.60 {
                    segColor = theme.primaryColor
                } else if segNorm < 0.85 {
                    segColor = Color(red: 1.0, green: 0.78, blue: 0.20) // Amber
                } else {
                    segColor = Color(red: 1.0, green: 0.28, blue: 0.25) // Peak Red
                }

                if s < activeSegments {
                    // Active lit LED
                    context.fill(segPath, with: .color(segColor))
                } else {
                    // Inactive dim unlit LED (gives authentic dark hardware rack grid look)
                    context.fill(segPath, with: .color(Color.primary.opacity(0.04)))
                }
            }

            // Draw floating peak hold indicator
            let peakY = size.height - CGFloat(activeSegments + 1) * totalSegmentStep - 2
            let peakRect = CGRect(x: x, y: max(0, peakY), width: barWidth, height: 2.0)
            let peakPath = Path(roundedRect: peakRect, cornerRadius: 0.8)
            let peakColor = (Double(activeSegments) / Double(maxSegments) > 0.8)
                ? Color(red: 1.0, green: 0.35, blue: 0.35)
                : Color.white.opacity(0.85)

            context.fill(peakPath, with: .color(peakColor))
        }
    }
}

#Preview("Studio Bars Visualizer") {
    ZStack {
        Color.black.ignoresSafeArea()
        StudioBarsVisualizerView(
            isPlaying: true,
            volume: 0.9,
            sensitivity: 1.0,
            theme: .aurora,
            barCount: 24
        )
        .frame(height: 160)
        .padding()
    }
}

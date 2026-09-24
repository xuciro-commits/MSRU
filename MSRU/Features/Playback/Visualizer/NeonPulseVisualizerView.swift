//
//  NeonPulseVisualizerView.swift
//  MSRU
//
//  High-fidelity glowing neon spectrum bars with vertical gradient and glass reflection.
//

import SwiftUI

public struct NeonPulseVisualizerView: View {
    public let isPlaying: Bool
    public var volume: Float = 1.0
    public var sensitivity: Double = 1.0
    public var theme: VisualizerColorTheme = .sunset
    public var barCount: Int = 22

    public init(
        isPlaying: Bool,
        volume: Float = 1.0,
        sensitivity: Double = 1.0,
        theme: VisualizerColorTheme = .sunset,
        barCount: Int = 22
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
                drawNeonBars(context: &context, size: size, time: time)
            }
        }
    }

    private func drawNeonBars(context: inout GraphicsContext, size: CGSize, time: Double) {
        guard size.width > 0 && size.height > 0 else { return }

        let count = barCount
        let spacing: CGFloat = 4.0
        let totalSpacing = spacing * CGFloat(count - 1)
        let barWidth = max(3.5, (size.width - totalSpacing) / CGFloat(count))
        let maxBarHeight = size.height * 0.78
        let baselineY = size.height * 0.82

        let gradient = Gradient(colors: [
            theme.primaryColor,
            theme.secondaryColor.opacity(0.85)
        ])

        for i in 0..<count {
            let energy = VisualizerEngine.computeBand(
                index: i,
                totalBands: count,
                time: time,
                isPlaying: isPlaying,
                volume: volume,
                sensitivity: sensitivity
            )

            let barH = max(4.0, maxBarHeight * CGFloat(energy))
            let x = CGFloat(i) * (barWidth + spacing)
            let y = baselineY - barH

            let barRect = CGRect(x: x, y: y, width: barWidth, height: barH)
            let barPath = Path(roundedRect: barRect, cornerRadius: barWidth * 0.5)

            // Primary bar fill with gradient
            context.fill(
                barPath,
                with: .linearGradient(
                    gradient,
                    startPoint: CGPoint(x: x, y: y),
                    endPoint: CGPoint(x: x, y: baselineY)
                )
            )

            // Ambient glow on high energy
            if energy > 0.65 && isPlaying {
                context.stroke(
                    barPath,
                    with: .color(theme.primaryColor.opacity(0.4)),
                    lineWidth: 2.0
                )
            }

            // Downward reflection
            let reflectH = barH * 0.35
            let reflectRect = CGRect(x: x, y: baselineY + 2, width: barWidth, height: reflectH)
            let reflectPath = Path(roundedRect: reflectRect, cornerRadius: barWidth * 0.5)
            let reflectGradient = Gradient(colors: [
                theme.secondaryColor.opacity(0.25),
                Color.clear
            ])

            context.fill(
                reflectPath,
                with: .linearGradient(
                    reflectGradient,
                    startPoint: CGPoint(x: x, y: baselineY + 2),
                    endPoint: CGPoint(x: x, y: baselineY + 2 + reflectH)
                )
            )
        }
    }
}

#Preview("Neon Pulse Visualizer") {
    ZStack {
        Color.black.ignoresSafeArea()
        NeonPulseVisualizerView(
            isPlaying: true,
            volume: 0.9,
            sensitivity: 1.0,
            theme: .sunset,
            barCount: 22
        )
        .frame(height: 160)
        .padding()
    }
}

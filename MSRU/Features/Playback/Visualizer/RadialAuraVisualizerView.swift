//
//  RadialAuraVisualizerView.swift
//  MSRU
//
//  Futuristic 360-degree radial sonic halo with energy spikes and pulsating central core.
//

import SwiftUI

public struct RadialAuraVisualizerView: View {
    public let isPlaying: Bool
    public var volume: Float = 1.0
    public var sensitivity: Double = 1.0
    public var theme: VisualizerColorTheme = .cyber

    public init(
        isPlaying: Bool,
        volume: Float = 1.0,
        sensitivity: Double = 1.0,
        theme: VisualizerColorTheme = .cyber
    ) {
        self.isPlaying = isPlaying
        self.volume = volume
        self.sensitivity = sensitivity
        self.theme = theme
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: isPlaying ? 1.0 / 30.0 : 1.0 / 6.0)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                drawRadial(context: &context, size: size, time: time)
            }
        }
    }

    private func drawRadial(context: inout GraphicsContext, size: CGSize, time: Double) {
        guard size.width > 0 && size.height > 0 else { return }

        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        let minDim = min(size.width, size.height)
        let baseRadius = minDim * 0.22
        let maxSpikeLength = minDim * 0.25

        // Central pulsating core
        let corePulse = isPlaying ? (sin(time * 4.2) + 1.0) * 0.5 * 4.0 : sin(time * 1.2) * 2.0
        let coreRadius = baseRadius + corePulse

        // Center halo glow
        let haloPath = Path(ellipseIn: CGRect(
            x: center.x - coreRadius,
            y: center.y - coreRadius,
            width: coreRadius * 2,
            height: coreRadius * 2
        ))

        context.stroke(
            haloPath,
            with: .color(theme.primaryColor.opacity(0.35)),
            lineWidth: 2.0
        )

        let innerCircle = Path(ellipseIn: CGRect(
            x: center.x - (coreRadius - 6),
            y: center.y - (coreRadius - 6),
            width: (coreRadius - 6) * 2,
            height: (coreRadius - 6) * 2
        ))
        context.fill(
            innerCircle,
            with: .color(theme.secondaryColor.opacity(0.12))
        )

        // Draw radial frequency spikes around the perimeter in a single batched path
        let spikeCount = 48
        let angleStep = (2.0 * .pi) / Double(spikeCount)
        var allSpikesPath = Path()

        for i in 0..<spikeCount {
            let angle = Double(i) * angleStep + (time * 0.15) // subtle continuous rotation
            let energy = VisualizerEngine.computeRadialSpike(
                angle: angle,
                time: time,
                isPlaying: isPlaying,
                volume: volume,
                sensitivity: sensitivity
            )

            let spikeLen = max(3.0, maxSpikeLength * CGFloat(energy))

            let cosA = cos(angle)
            let sinA = sin(angle)

            let startX = center.x + CGFloat(cosA) * (coreRadius + 3)
            let startY = center.y + CGFloat(sinA) * (coreRadius + 3)

            let endX = center.x + CGFloat(cosA) * (coreRadius + 3 + spikeLen)
            let endY = center.y + CGFloat(sinA) * (coreRadius + 3 + spikeLen)

            allSpikesPath.move(to: CGPoint(x: startX, y: startY))
            allSpikesPath.addLine(to: CGPoint(x: endX, y: endY))
        }

        // Render all spikes in 1 single GPU draw call
        context.stroke(
            allSpikesPath,
            with: .color(theme.primaryColor),
            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
        )
    }
}

#Preview("Radial Aura Visualizer") {
    ZStack {
        Color.black.ignoresSafeArea()
        RadialAuraVisualizerView(
            isPlaying: true,
            volume: 0.9,
            sensitivity: 1.0,
            theme: .cyber
        )
        .frame(width: 220, height: 220)
        .padding()
    }
}

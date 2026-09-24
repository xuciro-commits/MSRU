//
//  LiquidWaveVisualizerView.swift
//  MSRU
//
//  Multi-layer fluid dynamic wave visualizer with glowing crests and gradient mesh fill.
//

import SwiftUI

public struct LiquidWaveVisualizerView: View {
    public let isPlaying: Bool
    public var volume: Float = 1.0
    public var sensitivity: Double = 1.0
    public var theme: VisualizerColorTheme = .aurora

    public init(
        isPlaying: Bool,
        volume: Float = 1.0,
        sensitivity: Double = 1.0,
        theme: VisualizerColorTheme = .aurora
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
                drawWaves(context: &context, size: size, time: time)
            }
        }
    }

    private func drawWaves(context: inout GraphicsContext, size: CGSize, time: Double) {
        guard size.width > 0 && size.height > 0 else { return }

        let width = size.width
        let height = size.height

        // Draw 3 fluid overlapping wave layers from back to front
        let layers: [(layerIndex: Int, opacity: Double, strokeWidth: CGFloat)] = [
            (layerIndex: 0, opacity: 0.30, strokeWidth: 1.0),
            (layerIndex: 1, opacity: 0.55, strokeWidth: 1.5),
            (layerIndex: 2, opacity: 0.85, strokeWidth: 2.2)
        ]

        for layer in layers {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: height))

            let stepCount = 28
            let dx = width / CGFloat(stepCount)

            var crestPoints: [CGPoint] = []

            for i in 0...stepCount {
                let xNorm = Double(i) / Double(stepCount)
                let x = CGFloat(i) * dx
                let waveH = VisualizerEngine.computeWaveHeight(
                    x: xNorm,
                    time: time,
                    layerIndex: layer.layerIndex,
                    isPlaying: isPlaying,
                    volume: volume,
                    sensitivity: sensitivity
                )
                // Invert so wave rises from the bottom
                let y = height * (1.0 - CGFloat(waveH) * 0.88)
                let pt = CGPoint(x: x, y: y)
                crestPoints.append(pt)

                if i == 0 {
                    path.addLine(to: pt)
                } else {
                    let prev = crestPoints[i - 1]
                    let midX = (prev.x + pt.x) / 2
                    let midY = (prev.y + pt.y) / 2
                    path.addQuadCurve(to: CGPoint(x: midX, y: midY), control: prev)
                }
            }

            if let last = crestPoints.last {
                path.addLine(to: last)
            }
            path.addLine(to: CGPoint(x: width, y: height))
            path.closeSubpath()

            // Fill with smooth vertical gradient
            let fillGradient = Gradient(colors: [
                theme.secondaryColor.opacity(layer.opacity * 0.8),
                theme.primaryColor.opacity(layer.opacity * 0.4),
                Color.clear
            ])

            context.fill(
                path,
                with: .linearGradient(
                    fillGradient,
                    startPoint: CGPoint(x: width * 0.5, y: 0),
                    endPoint: CGPoint(x: width * 0.5, y: height)
                )
            )

            // Draw glowing crest line on top
            var crestPath = Path()
            if let first = crestPoints.first {
                crestPath.move(to: first)
                for pt in crestPoints.dropFirst() {
                    crestPath.addLine(to: pt)
                }

                let strokeColor = (layer.layerIndex == 2 ? theme.primaryColor : theme.secondaryColor)
                    .opacity(layer.opacity)

                context.stroke(
                    crestPath,
                    with: .color(strokeColor),
                    lineWidth: layer.strokeWidth
                )
            }
        }
    }
}

#Preview("Liquid Wave Visualizer") {
    ZStack {
        Color.black.ignoresSafeArea()
        LiquidWaveVisualizerView(
            isPlaying: true,
            volume: 0.9,
            sensitivity: 1.0,
            theme: .aurora
        )
        .frame(height: 180)
        .padding()
    }
}

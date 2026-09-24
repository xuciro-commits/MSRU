//
//  UnifiedVisualizerView.swift
//  MSRU
//
//  Composite dispatcher view seamlessly rendering any chosen visualizer style and color theme.
//

import SwiftUI

public struct UnifiedVisualizerView: View {
    public let style: VisualizerStyle
    public let theme: VisualizerColorTheme
    public let isPlaying: Bool
    public var volume: Float = 1.0
    public var sensitivity: Double = 1.0

    public init(
        style: VisualizerStyle = .liquidWave,
        theme: VisualizerColorTheme = .aurora,
        isPlaying: Bool,
        volume: Float = 1.0,
        sensitivity: Double = 1.0
    ) {
        self.style = style
        self.theme = theme
        self.isPlaying = isPlaying
        self.volume = volume
        self.sensitivity = sensitivity
    }

    public var body: some View {
        Group {
            switch style {
            case .liquidWave:
                LiquidWaveVisualizerView(
                    isPlaying: isPlaying,
                    volume: volume,
                    sensitivity: sensitivity,
                    theme: theme
                )
            case .studioBars:
                StudioBarsVisualizerView(
                    isPlaying: isPlaying,
                    volume: volume,
                    sensitivity: sensitivity,
                    theme: theme
                )
            case .radialAura:
                RadialAuraVisualizerView(
                    isPlaying: isPlaying,
                    volume: volume,
                    sensitivity: sensitivity,
                    theme: theme
                )
            case .neonPulse:
                NeonPulseVisualizerView(
                    isPlaying: isPlaying,
                    volume: volume,
                    sensitivity: sensitivity,
                    theme: theme
                )
            }
        }
        .animation(.easeInOut(duration: 0.35), value: style)
    }
}

#Preview("Unified Visualizer - Liquid") {
    ZStack {
        Color.black.ignoresSafeArea()
        UnifiedVisualizerView(
            style: .liquidWave,
            theme: .aurora,
            isPlaying: true
        )
        .frame(height: 180)
        .padding()
    }
}

#Preview("Unified Visualizer - Studio EQ") {
    ZStack {
        Color.black.ignoresSafeArea()
        UnifiedVisualizerView(
            style: .studioBars,
            theme: .aurora,
            isPlaying: true
        )
        .frame(height: 180)
        .padding()
    }
}

#Preview("Unified Visualizer - Radial Aura") {
    ZStack {
        Color.black.ignoresSafeArea()
        UnifiedVisualizerView(
            style: .radialAura,
            theme: .cyber,
            isPlaying: true
        )
        .frame(width: 200, height: 200)
        .padding()
    }
}

#Preview("Unified Visualizer - Neon Pulse") {
    ZStack {
        Color.black.ignoresSafeArea()
        UnifiedVisualizerView(
            style: .neonPulse,
            theme: .sunset,
            isPlaying: true
        )
        .frame(height: 180)
        .padding()
    }
}

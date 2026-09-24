//
//  VisualizerTypes.swift
//  MSRU
//
//  Data types, styles, and themes for real-time audio visualization.
//

import SwiftUI

// MARK: - Visualizer Style

public enum VisualizerStyle: String, CaseIterable, Identifiable, Sendable {
    case liquidWave = "liquidWave"
    case studioBars = "studioBars"
    case radialAura = "radialAura"
    case neonPulse = "neonPulse"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .liquidWave: return "Liquid Wave"
        case .studioBars: return "Studio EQ"
        case .radialAura: return "Radial Aura"
        case .neonPulse: return "Neon Pulse"
        }
    }

    public var localizedName: LocalizedStringKey {
        switch self {
        case .liquidWave: return "Liquid Wave"
        case .studioBars: return "Studio EQ"
        case .radialAura: return "Radial Aura"
        case .neonPulse: return "Neon Pulse"
        }
    }

    public var icon: String {
        switch self {
        case .liquidWave: return "water.waves"
        case .studioBars: return "chart.bar.xaxis"
        case .radialAura: return "circle.dashed"
        case .neonPulse: return "waveform.path"
        }
    }

    public var subtitle: String {
        switch self {
        case .liquidWave: return "Organic fluid flow with luminous wave crests"
        case .studioBars: return "Professional rack-mount hardware with peak hold"
        case .radialAura: return "Futuristic circular sonic halo & energy pulses"
        case .neonPulse: return "Vibrant Hi-Fi neon bars with glass reflection"
        }
    }
}

// MARK: - Visualizer Color Theme

public enum VisualizerColorTheme: String, CaseIterable, Identifiable, Sendable {
    case aurora = "aurora"
    case cyber = "cyber"
    case sunset = "sunset"
    case ocean = "ocean"
    case silver = "silver"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .aurora: return "Aurora"
        case .cyber: return "Cyberpunk"
        case .sunset: return "Sunset"
        case .ocean: return "Ocean"
        case .silver: return "Silver"
        }
    }

    public var primaryColor: Color {
        switch self {
        case .aurora: return Color(red: 0.15, green: 0.88, blue: 0.58)
        case .cyber: return Color(red: 0.85, green: 0.22, blue: 0.95)
        case .sunset: return Color(red: 1.0, green: 0.45, blue: 0.22)
        case .ocean: return Color(red: 0.15, green: 0.65, blue: 1.0)
        case .silver: return Color(white: 0.92)
        }
    }

    public var secondaryColor: Color {
        switch self {
        case .aurora: return Color(red: 0.10, green: 0.65, blue: 0.95)
        case .cyber: return Color(red: 0.22, green: 0.85, blue: 0.98)
        case .sunset: return Color(red: 0.98, green: 0.82, blue: 0.25)
        case .ocean: return Color(red: 0.35, green: 0.25, blue: 0.95)
        case .silver: return Color(white: 0.55)
        }
    }

    public var glowColor: Color {
        primaryColor.opacity(0.45)
    }

    public var gradientColors: [Color] {
        [secondaryColor, primaryColor]
    }
}

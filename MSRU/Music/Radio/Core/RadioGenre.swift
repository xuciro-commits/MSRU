//
//  RadioGenre.swift
//  MSRU
//

import Foundation

enum RadioGenre: String, CaseIterable, Identifiable, Codable, Sendable {
    case all = "All"
    case indie = "Indie & Alternative"
    case electronic = "Electronic & Chill"
    case classical = "Classical"
    case jazz = "Jazz & Blues"
    case pop = "Pop & Hits"
    case ambient = "Ambient & Drone"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .all:
            return "square.grid.2x2"
        case .indie:
            return "guitars"
        case .electronic:
            return "bolt.horizontal.circle"
        case .classical:
            return "pianokeys"
        case .jazz:
            return "waveform.and.mic"
        case .pop:
            return "sparkles"
        case .ambient:
            return "moon.stars"
        }
    }
}

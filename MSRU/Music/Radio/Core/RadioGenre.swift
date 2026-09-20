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

    var displayTitle: String {
        switch self {
        case .all: return "全部"
        case .indie: return "独立与另类"
        case .electronic: return "电子与氛围"
        case .classical: return "古典"
        case .jazz: return "爵士与蓝调"
        case .pop: return "流行与热门"
        case .ambient: return "环境与无人机音乐"
        }
    }

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

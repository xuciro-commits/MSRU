//
//  SubsonicServerProfile.swift
//  SubsonicKit
//
//  Server presets for guided setup (ZSpace, Navidrome, generic). User-facing
//  copy lives in the app, which owns localization.
//

import Foundation

public enum SubsonicServerPreset: String, CaseIterable, Identifiable, Sendable {
    case zspace = "zspace"
    case navidrome = "navidrome"
    case generic = "generic"

    public var id: String { rawValue }

    public var defaultPort: Int {
        switch self {
        case .zspace: return 8025
        case .navidrome: return 4533
        case .generic: return 4040
        }
    }

    public var iconName: String {
        switch self {
        case .zspace: return "externaldrive.connected.to.line.below.fill"
        case .navidrome: return "music.note.house.fill"
        case .generic: return "globe.americas.fill"
        }
    }

    public func formatDefaultURL(host: String) -> URL? {
        let cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanHost.starts(with: "http://") || cleanHost.starts(with: "https://") {
            return URL(string: cleanHost)
        }
        return URL(string: "http://\(cleanHost):\(defaultPort)")
    }
}

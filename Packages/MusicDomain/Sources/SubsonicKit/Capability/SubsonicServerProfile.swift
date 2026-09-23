//
//  SubsonicServerProfile.swift
//  SubsonicKit
//
//  Presets and server profiles for guided user onboarding (ZSpace, Navidrome, Generic).
//

import Foundation

public enum SubsonicServerPreset: String, CaseIterable, Identifiable, Sendable {
    case zspace = "zspace"
    case navidrome = "navidrome"
    case generic = "generic"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .zspace: return "极空间 (ZSpace)"
        case .navidrome: return "Navidrome"
        case .generic: return "通用 Subsonic / OpenSubsonic"
        }
    }

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

    public var helperInstructions: String {
        switch self {
        case .zspace:
            return "在极空间系统设置或音乐应用中开启「Subsonic 媒体库服务」，使用设置的专用用户名与密码连接。"
        case .navidrome:
            return "Navidrome 原生完全支持 OpenSubsonic 协议，输入服务器地址与常规登录凭证即可。"
        case .generic:
            return "支持所有兼容 Subsonic 1.16.1+ 与 OpenSubsonic 规范的音乐服务器（如 Gonic、LMS、Airsonic 等）。"
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

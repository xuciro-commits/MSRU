//
//  ManagedProvider.swift
//  MSRU
//

import Foundation

nonisolated enum ManagedProviderKind:
    String,
    Codable,
    Sendable {

    case builtIn
    case remote
}

nonisolated enum ManagedProviderCapability:
    String,
    Codable,
    CaseIterable,
    Identifiable,
    Hashable,
    Sendable {

    case catalog
    case metadata
    case playback
    case library

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .catalog:
            return "目录"

        case .metadata:
            return "元数据"

        case .playback:
            return "播放"

        case .library:
            return "资料库"
        }
    }
}

nonisolated enum ManagedProviderHealth:
    String,
    Codable,
    Sendable {

    case unknown
    case available
    case unavailable
}

nonisolated struct ManagedProvider:
    Identifiable,
    Codable,
    Hashable,
    Sendable {

    let id: UUID

    var key: String
    var name: String
    var summary: String
    var systemImage: String

    var kind: ManagedProviderKind
    var endpoint: String?

    var capabilities:
        Set<ManagedProviderCapability>

    var isEnabled: Bool
    var priority: Int

    var health:
        ManagedProviderHealth

    var lastTestMessage:
        String?

    var lastTestedAt:
        Date?

    var isRemovable:
        Bool

    init(
        id: UUID = UUID(),
        key: String,
        name: String,
        summary: String,
        systemImage: String,
        kind: ManagedProviderKind,
        endpoint: String? = nil,
        capabilities: Set<ManagedProviderCapability>,
        isEnabled: Bool,
        priority: Int,
        health: ManagedProviderHealth = .unknown,
        lastTestMessage: String? = nil,
        lastTestedAt: Date? = nil,
        isRemovable: Bool
    ) {
        self.id = id
        self.key = key
        self.name = name
        self.summary = summary
        self.systemImage = systemImage

        self.kind = kind
        self.endpoint = endpoint

        self.capabilities = capabilities

        self.isEnabled = isEnabled
        self.priority = priority

        self.health = health
        self.lastTestMessage = lastTestMessage
        self.lastTestedAt = lastTestedAt

        self.isRemovable = isRemovable
    }

    var isCustom: Bool {
        kind == .remote
    }

    var healthTitle: String {
        if !isEnabled {
            return "已停用"
        }

        switch health {
        case .unknown:
            return "未测试"

        case .available:
            return "可用"

        case .unavailable:
            return "不可用"
        }
    }
}

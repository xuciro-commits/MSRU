//
//  ManagedProvider.swift
//  MSRU
//

import Foundation
import MusicDomain

public nonisolated enum ManagedProviderKind:
    String,
    Codable,
    Sendable {

    case builtIn
    case remote
}

public nonisolated enum ManagedProviderCapability:
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

    public var id: Self {
        self
    }

    public var title: String {
        switch self {
        case .catalog:
            return String(localized: "Catalog")

        case .metadata:
            return String(localized: "Metadata")

        case .playback:
            return String(localized: "Playback")

        case .library:
            return String(localized: "Library")
        }
    }
}

public nonisolated enum ManagedProviderHealth:
    String,
    Codable,
    Sendable {

    case unknown
    case available
    case unavailable
}

public nonisolated struct ManagedProvider:
    Identifiable,
    Codable,
    Hashable,
    Sendable {

    public let id: UUID

    public var key: String
    public var name: String
    public var summary: String
    public var systemImage: String

    public var kind: ManagedProviderKind
    public var endpoint: String?

    public var capabilities:
        Set<ManagedProviderCapability>

    public var isEnabled: Bool
    public var priority: Int

    public var health:
        ManagedProviderHealth

    public var lastTestMessage:
        String?

    public var lastTestedAt:
        Date?

    public var isRemovable:
        Bool

    public init(
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

    public var isCustom: Bool {
        kind == .remote
    }

    public var healthTitle: String {
        if !isEnabled {
            return String(localized: "Disabled")
        }

        switch health {
        case .unknown:
            return String(localized: "Untested")

        case .available:
            return String(localized: "Available")

        case .unavailable:
            return String(localized: "Unavailable")
        }
    }
}

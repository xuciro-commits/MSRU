//
//  MetadataProviderConfigStore.swift
//  MSRU
//

import Foundation
import Observation
import SwiftUI

public enum MetadataProviderType: String, CaseIterable, Codable, Identifiable, Sendable {
    case appleMusic = "apple_music"
    case musicBrainz = "musicbrainz"
    case coverArtArchive = "cover_art_archive"
    case localEmbedded = "local_embedded"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .appleMusic: return "Apple Music (MusicKit)"
        case .musicBrainz: return "MusicBrainz 权威维基"
        case .coverArtArchive: return "Cover Art Archive (官方无损封面)"
        case .localEmbedded: return "本地内嵌音频标签 (ID3/Vorbis/APIC)"
        }
    }

    public var iconName: String {
        switch self {
        case .appleMusic: return "apple.logo"
        case .musicBrainz: return "globe.asia.australia.fill"
        case .coverArtArchive: return "photo.artframe"
        case .localEmbedded: return "tag.fill"
        }
    }

    public var providerDescription: String {
        switch self {
        case .appleMusic: return "官方 Apple 音乐目录，包含高品质官方专辑大图与权威艺术家信息。"
        case .musicBrainz: return "全球最大的开放音乐维基数据库，涵盖录音、发行版、流派标签与关系网络。"
        case .coverArtArchive: return "MetaBrainz 与互联网档案馆联合托管的全球官方唱片超清封面库。"
        case .localEmbedded: return "从本地音频文件自带的 ID3/Vorbis 标签和 APIC 封面图片中读取提取。"
        }
    }
}

@MainActor
@Observable
public final class MetadataProviderConfigStore {
    public static let shared = MetadataProviderConfigStore()

    public private(set) var enabledProviders: Set<MetadataProviderType> {
        didSet { save() }
    }

    public private(set) var providerPriority: [MetadataProviderType] {
        didSet { save() }
    }

    private let userDefaults: UserDefaults
    private let defaultsKey: String

    public init(userDefaults: UserDefaults = .standard, defaultsKey: String = "MSRU.MetadataProviderConfig") {
        self.userDefaults = userDefaults
        self.defaultsKey = defaultsKey

        if let data = userDefaults.data(forKey: defaultsKey),
           let saved = try? JSONDecoder().decode(SavedConfig.self, from: data) {
            self.enabledProviders = Set(saved.enabled)
            self.providerPriority = saved.priority
        } else {
            self.enabledProviders = Set(MetadataProviderType.allCases)
            self.providerPriority = [
                .appleMusic,
                .coverArtArchive,
                .musicBrainz,
                .localEmbedded
            ]
        }
    }

    public func isEnabled(_ provider: MetadataProviderType) -> Bool {
        enabledProviders.contains(provider)
    }

    public func toggle(_ provider: MetadataProviderType) {
        if enabledProviders.contains(provider) {
            // Keep at least one provider enabled
            if enabledProviders.count > 1 {
                enabledProviders.remove(provider)
            }
        } else {
            enabledProviders.insert(provider)
        }
    }

    public func setEnabled(_ provider: MetadataProviderType, isEnabled: Bool) {
        if isEnabled {
            enabledProviders.insert(provider)
        } else if enabledProviders.count > 1 {
            enabledProviders.remove(provider)
        }
    }

    public func move(from source: IndexSet, to destination: Int) {
        providerPriority.move(fromOffsets: source, toOffset: destination)
    }

    private func save() {
        let config = SavedConfig(enabled: Array(enabledProviders), priority: providerPriority)
        if let data = try? JSONEncoder().encode(config) {
            userDefaults.set(data, forKey: defaultsKey)
        }
    }

    private struct SavedConfig: Codable {
        let enabled: [MetadataProviderType]
        let priority: [MetadataProviderType]
    }
}

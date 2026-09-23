//
//  MetadataProviderConfigStore.swift
//  MSRU
//

import Foundation
import Observation
import MusicDomain

public enum MetadataProviderType: String, CaseIterable, Codable, Identifiable, Sendable {
    case appleMusic = "apple_music"
    case musicBrainz = "musicbrainz"
    case coverArtArchive = "cover_art_archive"
    case localEmbedded = "local_embedded"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .appleMusic: return "Apple Music (MusicKit)"
        case .musicBrainz: return String(localized: "MusicBrainz Authority")
        case .coverArtArchive: return String(localized: "Cover Art Archive (Hi-Res Covers)")
        case .localEmbedded: return String(localized: "Embedded Audio Tags (ID3/Vorbis/APIC)")
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
        case .appleMusic: return String(localized: "Official Apple Music catalog with high quality artwork and artist information.")
        case .musicBrainz: return String(localized: "World's largest open music encyclopedia covering recordings, releases, and relationships.")
        case .coverArtArchive: return String(localized: "Global repository of high-resolution album art hosted by MetaBrainz and Internet Archive.")
        case .localEmbedded: return String(localized: "Read from ID3/Vorbis tags and APIC cover art embedded in local files.")
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
        providerPriority.reorder(fromOffsets: source, toOffset: destination)
    }

    private func save() {
        let config = SavedConfig(enabled: Array(enabledProviders), priority: providerPriority)
        if let data = try? JSONEncoder().encode(config) {
            userDefaults.set(data, forKey: defaultsKey)
        }
    }

    private struct SavedConfig: Codable {
        public let enabled: [MetadataProviderType]
        public let priority: [MetadataProviderType]
    }
}

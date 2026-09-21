//
//  OpenverseAudio.swift
//  MSRU
//

import Foundation

nonisolated struct OpenverseAudio: Identifiable, Hashable, Decodable, Sendable {
    let id: String
    let title: String
    let creator: String?
    let mediaURLString: String
    let thumbnailURLString: String?
    let durationMilliseconds: Int?
    let filetype: String?
    let provider: String?
    let source: String?
    let license: String?
    let licenseVersion: String?
    let attribution: String?
    let descriptionText: String?
    let landingURLString: String?

    // MARK: - Init

    init(
        id: String,
        title: String,
        creator: String? = nil,
        mediaURLString: String,
        thumbnailURLString: String? = nil,
        durationMilliseconds: Int? = nil,
        filetype: String? = nil,
        provider: String? = nil,
        source: String? = nil,
        license: String? = nil,
        licenseVersion: String? = nil,
        attribution: String? = nil,
        descriptionText: String? = nil,
        landingURLString: String? = nil
    ) {
        self.id = id
        self.title = title
        self.creator = creator
        self.mediaURLString = mediaURLString
        self.thumbnailURLString = thumbnailURLString
        self.durationMilliseconds = durationMilliseconds
        self.filetype = filetype
        self.provider = provider
        self.source = source
        self.license = license
        self.licenseVersion = licenseVersion
        self.attribution = attribution
        self.descriptionText = descriptionText
        self.landingURLString = landingURLString
    }

    // MARK: - Decodable

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case creator
        case mediaURLString = "url"
        case thumbnailURLString = "thumbnail"
        case durationMilliseconds = "duration"
        case filetype
        case provider
        case source
        case license
        case licenseVersion = "license_version"
        case attribution
        case descriptionText = "description"
        case landingURLString = "foreign_landing_url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = (try? container.decode(String.self, forKey: .title)) ?? "Untitled"
        creator = try? container.decodeIfPresent(String.self, forKey: .creator)
        mediaURLString = try container.decode(String.self, forKey: .mediaURLString)
        thumbnailURLString = try? container.decodeIfPresent(String.self, forKey: .thumbnailURLString)
        durationMilliseconds = try? container.decodeIfPresent(Int.self, forKey: .durationMilliseconds)
        filetype = try? container.decodeIfPresent(String.self, forKey: .filetype)
        provider = try? container.decodeIfPresent(String.self, forKey: .provider)
        source = try? container.decodeIfPresent(String.self, forKey: .source)
        license = try? container.decodeIfPresent(String.self, forKey: .license)
        licenseVersion = try? container.decodeIfPresent(String.self, forKey: .licenseVersion)
        attribution = try? container.decodeIfPresent(String.self, forKey: .attribution)
        descriptionText = try? container.decodeIfPresent(String.self, forKey: .descriptionText)
        landingURLString = try? container.decodeIfPresent(String.self, forKey: .landingURLString)
    }

    // MARK: - URLs

    var mediaURL: URL? {
        URL(string: mediaURLString)
    }

    var thumbnailURL: URL? {
        guard let thumbnailURLString else { return nil }
        return URL(string: thumbnailURLString)
    }

    // MARK: - Presentation

    var creatorTitle: String {
        let value = creator?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty else {
            return "Unknown Artist"
        }
        return value
    }

    var sourceTitle: String {
        let upstream = provider ?? source ?? "Openverse"
        return upstream.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var licenseTitle: String {
        guard let license, !license.isEmpty else {
            return "Open license"
        }
        if let licenseVersion, !licenseVersion.isEmpty {
            return "\(license.uppercased()) \(licenseVersion)"
        }
        return license.uppercased()
    }

    var summaryText: String {
        if let descriptionText {
            let cleaned = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty {
                return cleaned
            }
        }
        if let attribution {
            let cleaned = attribution.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty {
                return cleaned
            }
        }
        return "\(sourceTitle) · \(licenseTitle)"
    }

    var durationText: String? {
        guard let durationMilliseconds, durationMilliseconds > 0 else {
            return nil
        }
        let totalSeconds = durationMilliseconds / 1_000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Playback Capability

    var prefersNativePlayback: Bool {
        guard let filetype else { return true }
        let normalized = filetype.lowercased()
        return normalized.contains("mp3")
            || normalized.contains("mp32")
            || normalized.contains("mpeg")
            || normalized.contains("m4a")
            || normalized.contains("aac")
            || normalized.contains("wav")
    }
}

// MARK: - Response

nonisolated struct OpenverseAudioSearchResponse: Decodable, Sendable {
    let results: [OpenverseAudio]
}

// MARK: - Catalog Provider

nonisolated enum OpenverseCatalogError: LocalizedError, Sendable {
    case invalidRequest
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Unable to create the Openverse request."
        case .invalidResponse:
            return "Openverse returned an invalid response."
        case .httpStatus(let status):
            return "Openverse returned HTTP \(status)."
        }
    }
}

nonisolated struct OpenverseCatalogProvider: Sendable {
    private let baseURL = "https://api.openverse.org/v1/audio/"

    func search(_ query: String, pageSize: Int = 12) async throws -> [OpenverseAudio] {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty,
              var components = URLComponents(string: baseURL) else {
            return []
        }

        components.queryItems = [
            URLQueryItem(name: "q", value: cleaned),
            URLQueryItem(name: "page_size", value: String(max(1, min(pageSize, 20))))
        ]

        guard let url = components.url else {
            throw OpenverseCatalogError.invalidRequest
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("MSRU/0.1 OpenverseProvider", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OpenverseCatalogError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            throw OpenverseCatalogError.httpStatus(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(OpenverseAudioSearchResponse.self, from: data)
        return decoded.results
            .filter { $0.mediaURL != nil }
            .sorted { lhs, rhs in
                if lhs.prefersNativePlayback != rhs.prefersNativePlayback {
                    return lhs.prefersNativePlayback
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }
}

// MARK: - Search Client

nonisolated struct OpenverseSearchClient: Sendable {
    let search: @Sendable (String) async throws -> [OpenverseAudio]

    init(search: @escaping @Sendable (String) async throws -> [OpenverseAudio]) {
        self.search = search
    }
}

nonisolated extension OpenverseSearchClient {
    static let live = OpenverseSearchClient { query in
        try await OpenverseCatalogProvider().search(query)
    }

    static func preview(results: [OpenverseAudio]) -> Self {
        Self { query in
            let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !cleaned.isEmpty else { return [] }
            return results.filter { item in
                item.title.lowercased().contains(cleaned)
                    || item.creatorTitle.lowercased().contains(cleaned)
            }
        }
    }
}

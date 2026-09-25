//
//  SceneNavigation.swift
//  MSRU
//

import Foundation
import Observation
import AppFoundation

// MARK: - MSRU Routing Bindings

typealias SceneID = AppFoundation.SceneID
typealias SceneRoutingTarget = AppFoundation.SceneRoutingTarget
typealias SceneRoutingRequest = AppFoundation.SceneRoutingRequest<SceneRoute>
typealias SceneCommand = AppFoundation.SceneCommand<SceneRoute>
typealias ApplicationCommand = AppFoundation.ApplicationCommand<SceneRoute>

// MARK: - Scene Root Section

nonisolated enum SceneSection:
    String,
    Codable,
    CaseIterable,
    Identifiable,
    Hashable,
    Sendable {

    case listenNow
    case browse
    case radio

    case library
    case albums
    case artists
    case playlists
    case sources

    case importReview

    case settings

    var id: Self {
        self
    }

    /// Reads a section from a restoration record or URL. Raw values of retired
    /// sections map to the section that replaced them, so records written by
    /// earlier versions reopen the right place instead of being dropped.
    init?(persistedValue: String) {
        switch persistedValue {
        case "addMusic": self = .sources
        default: self.init(rawValue: persistedValue)
        }
    }

    init(from decoder: any Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        guard let section = SceneSection(persistedValue: value) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unknown scene section \(value)")
            )
        }
        self = section
    }
}

// MARK: - Scene Route

nonisolated enum SceneRoute:
    Codable,
    Equatable,
    Hashable,
    Sendable {

    case section(SceneSection)

    var rootSection: SceneSection {
        switch self {
        case .section(let section):
            return section
        }
    }
}

// MARK: - Scene Navigation

@MainActor
@Observable
final class SceneNavigation {
    private(set) var section: SceneSection

    var route: SceneRoute {
        .section(section)
    }

    init(section: SceneSection = .listenNow) {
        self.section = section
    }

    func navigate(to route: SceneRoute) {
        switch route {
        case .section(let section):
            self.section = section
        }
    }

    func select(_ section: SceneSection) {
        navigate(to: .section(section))
    }

    func reset() {
        navigate(to: .section(.listenNow))
    }
}

// MARK: - Scene Route URL Codec

nonisolated struct SceneRouteURLCodec: Sendable {
    let scheme: String

    init(scheme: String) {
        self.scheme = scheme.lowercased()
    }

    func decode(_ url: URL) -> SceneRoute? {
        guard url.scheme?.lowercased() == scheme else { return nil }
        guard url.host?.lowercased() == "section" else { return nil }

        let pathComponents = url.path.split(separator: "/")
        guard pathComponents.count == 1 else { return nil }

        let rawValue = String(pathComponents[0])
        guard let section = SceneSection(persistedValue: rawValue) else { return nil }

        return .section(section)
    }

    func encode(_ route: SceneRoute) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        switch route {
        case .section(let section):
            components.host = "section"
            components.path = "/" + section.rawValue
        }
        return components.url
    }
}

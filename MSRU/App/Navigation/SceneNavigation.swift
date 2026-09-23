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

    case addMusic
    case importReview

    case settings

    var id: Self {
        self
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
        guard let section = SceneSection(rawValue: rawValue) else { return nil }

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

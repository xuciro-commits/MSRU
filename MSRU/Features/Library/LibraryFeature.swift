//
//  LibraryFeature.swift
//  MSRU
//

import Foundation
import Observation
import SwiftUI
import AppFoundation
import AppFoundationUI
import MusicLibrary
import MusicPlayback


// MARK: - Feature

/// The Library destination. Its only own state is which web tracks are being
/// removed; everything else is read from the shared stores.
enum LibraryFeature:
    Feature {

    @MainActor
    @Observable
    final class State {
        fileprivate(set) var pendingRemovalIDs: Set<String> = []
    }

    enum Action {
        /// Removes web tracks (identified by `LocalTrack.id`) from the Library.
        case removeWebTracksRequested(Set<String>)
        case removeWebTracksFinished(Set<String>)
    }

    @MainActor
    static func makeInitialState() -> State {
        State()
    }

    @MainActor
    struct Service: FeatureService {
        @Dependency(\.webLibrary) private var webLibrary: WebLibraryStore

        init() {}

        var webTracks: [LocalTrack] { webLibrary.tracks }
        var errorMessage: String? { webLibrary.errorMessage }

        func handle(_ action: Action, state: State) -> [FeatureTask<Action>] {
            switch action {
            case .removeWebTracksRequested(let ids):
                let pending = ids.subtracting(state.pendingRemovalIDs)
                guard !pending.isEmpty else { return [] }
                state.pendingRemovalIDs.formUnion(pending)
                return [
                    .run(id: "library.remove.\(pending.sorted().joined(separator: ","))", cancelInFlight: true) { send in
                        await webLibrary.remove(trackIDs: pending)
                        guard !Task.isCancelled else { return }
                        send(.removeWebTracksFinished(pending))
                    }
                ]
            case .removeWebTracksFinished(let ids):
                state.pendingRemovalIDs.subtract(ids)
                return []
            }
        }
    }
}

// MARK: - Runtime Projection

@MainActor
extension FeatureHost where F == LibraryFeature {
    var webTracks: [LocalTrack] { service.webTracks }
    var errorMessage: String? { service.errorMessage }

    func isRemoving(_ track: LocalTrack) -> Bool {
        state.pendingRemovalIDs.contains(track.id)
    }
}

// MARK: - Application Contribution

extension LibraryFeature: ApplicationFeature {

    typealias Route = SceneRoute

    nonisolated static var contributions: FeatureContribution<Route> {
        FeatureContribution(
            sidebar: [
                SidebarContribution(
                    id: "library",
                    group: "Library",
                    title: "Songs",
                    systemImage: "music.note",
                    route: SceneRoute.section(.library),
                    order: 100
                )
            ],
            routes: [
                RouteContribution(
                    id: "library",
                    route: SceneRoute.section(.library)
                )
            ]
        )
    }
}

// MARK: - Application Presentation

extension LibraryFeature: ApplicationFeaturePresentation {

    typealias PresentationContext = SceneModel

    static var routeDestinations: [RouteDestination<SceneRoute, SceneModel>] {
        [
            RouteDestination(
                id: "library",
                route: .section(.library),
                workspace: { scene in
                    WorkspacePresentation(
                        identity: WorkspaceIdentity(
                            title: "Songs",
                            systemImage: "music.note"
                        ),
                        toolbar: libraryToolbar
                    ) { _ in
                        LibraryFeatureDestination(scene: scene)
                    }
                }
            )
        ]
    }

    // MARK: - Workspace Toolbar

    private static var libraryToolbar: ToolbarPresentation<SceneModel> {
        ToolbarPresentation(
            items: [
                .search(
                    ToolbarSearchPresentation(
                        id: "library.search",
                        prompt: String(localized: "Filter songs…"),
                        text: { scene in
                            scene.librarySearchQuery
                        },
                        update: { scene, value in
                            scene.librarySearchQuery = value
                        }
                    )
                )
            ]
        )
    }
}

// MARK: - Destination Adapter

private struct LibraryFeatureDestination: View {

    @Bindable var scene: SceneModel

    var body: some View {
        LibraryView(
            feature: scene.libraryFeature,
            localStore: scene.application.localLibrary,
            subsonicServers: scene.application.subsonicServers,
            playback: scene.application.playback,
            searchQuery: $scene.librarySearchQuery,
            selectedLocalTrack: Binding(
                get: { scene.selectedLocalTrack },
                set: { scene.select(localTrack: $0) }
            ),
            selectedSourceID: Binding(
                get: { scene.selectedSourceFilter },
                set: { scene.selectedSourceFilter = $0 }
            ),
            onAddMusic: {
                scene.send(.navigate(.section(.addMusic)))
            }
        )
    }
}

#Preview("Library Destination") {
    LibraryFeatureDestination(scene: MSRUPreviewData.makeScene(section: .library))
        .frame(width: 900, height: 650)
}


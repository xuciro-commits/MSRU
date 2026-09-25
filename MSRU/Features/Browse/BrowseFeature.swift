//
//  BrowseFeature.swift
//  MSRU
//

import Foundation
import Observation
import SwiftUI
import AppFoundation
import AppFoundationUI
import MusicLibrary
import MusicPlayback

// MARK: - Feature Definition

enum BrowseFeature: Feature {

    // MARK: State

    @MainActor
    @Observable
    final class State {
        fileprivate(set) var query: String
        fileprivate(set) var results: [OpenverseAudio]
        fileprivate(set) var isLoading: Bool
        fileprivate(set) var errorMessage: String?
        fileprivate var hasAppeared = false

        init(
            query: String = "mozart",
            results: [OpenverseAudio] = [],
            isLoading: Bool = false,
            errorMessage: String? = nil
        ) {
            self.query = query
            self.results = results
            self.isLoading = isLoading
            self.errorMessage = errorMessage
        }
    }

    // MARK: Action

    enum Action {
        case appeared
        case queryChanged(String)
        case retryRequested
        case searchRequested(String)
        case searchSucceeded(query: String, results: [OpenverseAudio])
        case searchFailed(query: String, message: String)
        case playPauseRequested(OpenverseAudio)
        case playNextRequested(OpenverseAudio)
        case addToQueueRequested(OpenverseAudio)
        case libraryToggleRequested(OpenverseAudio)
        case libraryMutationFinished
    }

    // MARK: Initial State

    @MainActor
    static func makeInitialState() -> State {
        State()
    }

    // MARK: Service

    @MainActor
    struct Service: FeatureService {

        // MARK: Task IDs
        private enum TaskID {
            static let debounce: FeatureTaskID = "browse.search.debounce"
            static let request: FeatureTaskID = "browse.search.request"
        }

        // MARK: Dependencies
        @Dependency(\.openverseSearch) private var searchClient: OpenverseSearchClient
        @Dependency(\.playback) private var playback: PlaybackController
        @Dependency(\.webLibrary) private var library: WebLibraryStore

        init() {}

        // MARK: Derived UI State

        var isPlaying: Bool {
            playback.isPlaying
        }

        func isCurrent(_ item: OpenverseAudio) -> Bool {
            playback.currentItem?.openverseTrack?.id == item.id
        }

        func isSaved(_ item: OpenverseAudio) -> Bool {
            library.contains(openverseID: item.id)
        }

        var libraryErrorMessage: String? {
            library.errorMessage
        }

        // MARK: Handle

        func handle(_ action: Action, state: State) -> [FeatureTask<Action>] {
            switch action {
            // MARK: Lifecycle
            case .appeared:
                guard !state.hasAppeared else { return [] }
                state.hasAppeared = true

                let cleaned = state.query.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleaned.isEmpty {
                    state.query = "mozart"
                }

                guard state.results.isEmpty else { return [] }

                let query = normalizedQuery(state.query)
                guard !query.isEmpty else { return [] }

                state.isLoading = true
                state.errorMessage = nil

                return [requestTask(query: query)]

            // MARK: Query
            case .queryChanged(let value):
                state.query = value
                state.errorMessage = nil
                state.isLoading = false

                let query = normalizedQuery(value)
                guard !query.isEmpty else {
                    state.results = []
                    return [
                        .cancel(id: TaskID.debounce),
                        .cancel(id: TaskID.request)
                    ]
                }

                return [
                    .cancel(id: TaskID.request),
                    .run(id: TaskID.debounce, cancelInFlight: true) { send in
                        do {
                            try await Task.sleep(nanoseconds: 350_000_000)
                        } catch {
                            return
                        }

                        guard !Task.isCancelled else { return }
                        send(.searchRequested(query))
                    }
                ]

            // MARK: Retry
            case .retryRequested:
                let query = normalizedQuery(state.query)
                guard !query.isEmpty else { return [] }

                state.isLoading = true
                state.errorMessage = nil

                return [
                    .cancel(id: TaskID.debounce),
                    requestTask(query: query)
                ]

            // MARK: Begin Search
            case .searchRequested(let query):
                guard normalizedQuery(state.query) == query else { return [] }

                state.isLoading = true
                state.errorMessage = nil

                return [requestTask(query: query)]

            // MARK: Search Success
            case .searchSucceeded(let query, let results):
                guard normalizedQuery(state.query) == query else { return [] }

                state.results = results
                state.isLoading = false
                state.errorMessage = nil
                return []

            // MARK: Search Failure
            case .searchFailed(let query, let message):
                guard normalizedQuery(state.query) == query else { return [] }

                state.results = []
                state.isLoading = false
                state.errorMessage = message
                return []

            // MARK: Playback
            case .playPauseRequested(let item):
                playback.toggle(openverse: item, queue: state.results)
                return []

            case .playNextRequested(let item):
                playback.playNext(openverse: item)
                return []

            case .addToQueueRequested(let item):
                playback.addToQueue(openverse: item)
                return []

            // MARK: Library
            case .libraryToggleRequested(let item):
                let isSaved = library.contains(openverseID: item.id)
                return [
                    .run(id: "browse.library.\(item.id)", cancelInFlight: true) { send in
                        if isSaved {
                            await library.remove(openverseID: item.id)
                        } else {
                            await library.add(openverse: item)
                        }

                        guard !Task.isCancelled else { return }
                        send(.libraryMutationFinished)
                    }
                ]

            case .libraryMutationFinished:
                return []
            }
        }

        // MARK: Search Task

        private func requestTask(query: String) -> FeatureTask<Action> {
            .run(id: TaskID.request, cancelInFlight: true) { send in
                do {
                    let results = try await searchClient.search(query)
                    guard !Task.isCancelled else { return }
                    send(.searchSucceeded(query: query, results: results))
                } catch is CancellationError {
                    return
                } catch {
                    guard !Task.isCancelled else { return }
                    send(.searchFailed(query: query, message: error.localizedDescription))
                }
            }
        }

        // MARK: Query

        private func normalizedQuery(_ value: String) -> String {
            value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

// MARK: - Browse Runtime Projection

@MainActor
extension FeatureHost where F == BrowseFeature {
    var libraryErrorMessage: String? { service.libraryErrorMessage }
    var isPlaying: Bool { service.isPlaying }

    func isCurrent(_ item: OpenverseAudio) -> Bool {
        service.isCurrent(item)
    }

    func isSaved(_ item: OpenverseAudio) -> Bool {
        service.isSaved(item)
    }
}

// MARK: - Application Contribution

extension BrowseFeature: ApplicationFeature {
    typealias Route = SceneRoute

    nonisolated static var contributions: FeatureContribution<Route> {
        FeatureContribution(
            sidebar: [
                SidebarContribution(
                    id: "browse",
                    group: "Discover",
                    title: "Browse",
                    systemImage: "sparkles",
                    route: SceneRoute.section(.browse),
                    order: 20
                )
            ],
            routes: [
                RouteContribution(
                    id: "browse",
                    route: SceneRoute.section(.browse)
                )
            ]
        )
    }
}

// MARK: - Application Presentation

extension BrowseFeature: ApplicationFeaturePresentation {
    typealias PresentationContext = SceneModel

    static var routeDestinations: [RouteDestination<SceneRoute, SceneModel>] {
        [
            RouteDestination(
                id: "browse",
                route: .section(.browse),
                workspace: { scene in
                    WorkspacePresentation(
                        identity: WorkspaceIdentity(
                            title: String(localized: "Browse"),
                            systemImage: "square.grid.2x2"
                        ),
                        toolbar: browseToolbar
                    ) { _ in
                        BrowseView(feature: scene.browse)
                    }
                }
            )
        ]
    }

    // MARK: - Workspace Toolbar

    private static var browseToolbar: ToolbarPresentation<SceneModel> {
        ToolbarPresentation(
            items: [
                .search(
                    ToolbarSearchPresentation(
                        id: "browse.search",
                        prompt: String(localized: "Search Openverse"),
                        text: { scene in
                            scene.browse.state.query
                        },
                        update: { scene, value in
                            scene.browse.send(.queryChanged(value))
                        }
                    )
                )
            ]
        )
    }
}

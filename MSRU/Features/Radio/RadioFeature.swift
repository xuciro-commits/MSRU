//
//  RadioFeature.swift
//  MSRU
//

import SwiftUI
import Observation
import AppFoundation
import AppFoundationUI
import MusicLibrary
import MusicPlayback

// MARK: - Feature Definition

enum RadioFeature: Feature {

    // MARK: State

    @MainActor
    @Observable
    final class State {

        fileprivate(set) var selectedGenre: RadioGenre
        fileprivate(set) var searchQuery: String
        fileprivate(set) var stations: [RadioStation]
        fileprivate(set) var featuredStations: [RadioStation]
        fileprivate(set) var favoriteStations: [RadioStation]
        fileprivate(set) var recentStations: [RadioStation]
        fileprivate(set) var favoriteIDs: Set<String>
        fileprivate var hasAppeared = false

        init(
            selectedGenre: RadioGenre = .all,
            searchQuery: String = "",
            stations: [RadioStation] = [],
            featuredStations: [RadioStation] = [],
            favoriteStations: [RadioStation] = [],
            recentStations: [RadioStation] = [],
            favoriteIDs: Set<String> = []
        ) {
            self.selectedGenre = selectedGenre
            self.searchQuery = searchQuery
            self.stations = stations
            self.featuredStations = featuredStations
            self.favoriteStations = favoriteStations
            self.recentStations = recentStations
            self.favoriteIDs = favoriteIDs
        }

        func isFavorite(_ station: RadioStation) -> Bool {
            favoriteIDs.contains(station.id)
        }
    }

    // MARK: Action

    enum Action {
        case appeared
        case genreSelected(RadioGenre)
        case searchQueryChanged(String)
        case playPauseRequested(RadioStation)
        case playNextRequested(RadioStation)
        case addToQueueRequested(RadioStation)
        case toggleFavoriteRequested(RadioStation)
        case addCustomStationRequested(RadioStation)
        case deleteCustomStationRequested(String)
    }

    // MARK: Initial State

    @MainActor
    static func makeInitialState() -> State {
        State()
    }

    // MARK: Service

    @MainActor
    struct Service: FeatureService {

        @Dependency(\.radioStore)
        private var radioStore: RadioStore

        @Dependency(\.playback)
        private var playback: PlaybackController

        init() {}

        // MARK: Derived UI State

        var isPlaying: Bool {
            playback.isPlaying
        }

        func isCurrent(_ station: RadioStation) -> Bool {
            playback.currentItem?.radioStation?.id == station.id
        }

        func state(for station: RadioStation) -> TrackPlaybackState {
            playback.state(for: station)
        }

        func isFavorite(_ station: RadioStation) -> Bool {
            radioStore.isFavorite(id: station.id)
        }

        // MARK: Handle

        func handle(_ action: Action, state: State) -> [FeatureTask<Action>] {
            switch action {
            case .appeared:
                guard !state.hasAppeared else { return [] }
                state.hasAppeared = true
                refreshStations(state: state)
                return []

            case .genreSelected(let genre):
                state.selectedGenre = genre
                refreshStations(state: state)
                return []

            case .searchQueryChanged(let query):
                state.searchQuery = query
                refreshStations(state: state)
                return []

            case .playPauseRequested(let station):
                radioStore.recordPlayed(station: station)
                playback.toggle(radio: station, queue: state.stations)
                refreshStations(state: state)
                return []

            case .playNextRequested(let station):
                playback.playNext(radio: station)
                return []

            case .addToQueueRequested(let station):
                playback.addToQueue(radio: station)
                return []

            case .toggleFavoriteRequested(let station):
                radioStore.toggleFavorite(id: station.id)
                refreshStations(state: state)
                return []

            case .addCustomStationRequested(let station):
                radioStore.addCustomStation(station)
                refreshStations(state: state)
                return []

            case .deleteCustomStationRequested(let id):
                radioStore.deleteCustomStation(id: id)
                refreshStations(state: state)
                return []
            }
        }

        private func refreshStations(state: State) {
            state.favoriteIDs = radioStore.favoriteIDs
            state.featuredStations = radioStore.featuredStations
            state.favoriteStations = radioStore.favoriteStations
            state.recentStations = radioStore.recentStations
            state.stations = radioStore.filteredStations(
                genre: state.selectedGenre,
                query: state.searchQuery
            )
        }
    }
}

// MARK: - FeatureHost Projection

@MainActor
extension FeatureHost where F == RadioFeature {

    var isPlaying: Bool {
        service.isPlaying
    }

    func isCurrent(_ station: RadioStation) -> Bool {
        service.isCurrent(station)
    }

    func state(for station: RadioStation) -> TrackPlaybackState {
        service.state(for: station)
    }

    func isFavorite(_ station: RadioStation) -> Bool {
        state.isFavorite(station)
    }
}

// MARK: - Application Contribution

extension RadioFeature: ApplicationFeature {

    typealias Route = SceneRoute

    nonisolated static var contributions: FeatureContribution<Route> {
        FeatureContribution(
            sidebar: [
                SidebarContribution(
                    id: "radio",
                    group: "Discover",
                    title: "Radio",
                    systemImage: "dot.radiowaves.left.and.right",
                    route: SceneRoute.section(.radio),
                    order: 30
                )
            ],
            routes: [
                RouteContribution(
                    id: "radio",
                    route: SceneRoute.section(.radio)
                )
            ]
        )
    }
}

// MARK: - Application Presentation

extension RadioFeature: ApplicationFeaturePresentation {

    typealias PresentationContext = SceneModel

    static var routeDestinations: [RouteDestination<SceneRoute, SceneModel>] {
        [
            RouteDestination(
                id: "radio",
                route: .section(.radio),
                workspace: { scene in
                    WorkspacePresentation(
                        identity: WorkspaceIdentity(
                            title: String(localized: "Radio"),
                            systemImage: "dot.radiowaves.left.and.right"
                        ),
                        toolbar: radioToolbar
                    ) { _ in
                        RadioView(
                            feature: scene.radioFeature,
                            selectedStation: scene.selectedRadioStation,
                            onSelectStation: { station in
                                scene.select(radioStation: station)
                            }
                        )
                    }
                }
            )
        ]
    }

    // MARK: - Workspace Toolbar

    private static var radioToolbar: ToolbarPresentation<SceneModel> {
        ToolbarPresentation(
            items: [
                .search(
                    ToolbarSearchPresentation(
                        id: "radio.search",
                        prompt: String(localized: "Search stations, genres, or countries"),
                        text: { scene in
                            scene.radioFeature.state.searchQuery
                        },
                        update: { scene, value in
                            scene.radioFeature.send(
                                .searchQueryChanged(value)
                            )
                        }
                    )
                )
            ]
        )
    }
}

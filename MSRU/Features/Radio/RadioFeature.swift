//
//  RadioFeature.swift
//  MSRU
//

import Foundation
import Observation
import AppFoundation

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
        fileprivate var hasAppeared = false

        init(
            selectedGenre: RadioGenre = .all,
            searchQuery: String = "",
            stations: [RadioStation] = [],
            featuredStations: [RadioStation] = []
        ) {
            self.selectedGenre = selectedGenre
            self.searchQuery = searchQuery
            self.stations = stations
            self.featuredStations = featuredStations
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
                playback.toggle(radio: station, queue: state.stations)
                return []

            case .playNextRequested(let station):
                playback.playNext(radio: station)
                return []

            case .addToQueueRequested(let station):
                playback.addToQueue(radio: station)
                return []
            }
        }

        private func refreshStations(state: State) {
            state.featuredStations = radioStore.featuredStations
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
}

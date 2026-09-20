//
//  RadioView.swift
//  MSRU
//

import SwiftUI
import Observation
import AppFoundation
import AppFoundationUI

struct RadioView: View {

    let feature: FeatureHost<RadioFeature>
    var selectedStation: RadioStation? = nil
    var onSelectStation: ((RadioStation) -> Void)? = nil

    @Bindable private var state: RadioFeature.State
    @State private var isShowingAddStationSheet = false

    private let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 260), spacing: 18)
    ]

    init(
        feature: FeatureHost<RadioFeature>,
        selectedStation: RadioStation? = nil,
        onSelectStation: ((RadioStation) -> Void)? = nil
    ) {
        self.feature = feature
        self.selectedStation = selectedStation
        self.onSelectStation = onSelectStation
        self._state = Bindable(wrappedValue: feature.state)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 26) {
                header
                genreFilterBar

                if state.searchQuery.isEmpty {
                    if !state.favoriteStations.isEmpty {
                        favoritesSection
                    }

                    if let heroStation = featuredHeroStation {
                        featuredSection(heroStation)
                    }

                    if !state.recentStations.isEmpty {
                        recentlyPlayedSection
                    }
                }

                stationsGridSection
            }
            .padding(28)
        }
        .scrollIndicators(.hidden)
        .hideScrollIndicatorsCompletely()
        .sheet(isPresented: $isShowingAddStationSheet) {
            AddStationSheetView { newStation in
                feature.send(.addCustomStationRequested(newStation))
            }
        }
        .task {
            feature.send(.appeared)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Radio")
                    .font(.system(size: 32, weight: .bold))

                Text("Featured internet live radio stations, supporting lossless and high-bitrate playback.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                isShowingAddStationSheet = true
            } label: {
                Label("Add Station", systemImage: "plus")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
    }

    // MARK: - Genre Filter Bar

    private var genreFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RadioGenre.allCases) { genre in
                    let isSelected = state.selectedGenre == genre
                    Button {
                        feature.send(.genreSelected(genre))
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: genre.systemImage)
                                .font(.system(size: 11, weight: .semibold))
                            Text(LocalizedStringKey(genre.rawValue))
                                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            isSelected ? Color.accentColor : Color.primary.opacity(0.06)
                        )
                        .foregroundStyle(
                            isSelected ? Color.white : Color.primary
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
        .hideScrollIndicatorsCompletely()
    }

    // MARK: - Favorites Section

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                Text("Favorite")
                    .font(.title3.bold())
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(state.favoriteStations) { station in
                        RadioStationCardView(
                            station: station,
                            isSelected: selectedStation?.id == station.id,
                            isCurrent: feature.isCurrent(station),
                            playbackState: feature.state(for: station),
                            isFavorite: true,
                            onToggleFavorite: {
                                feature.send(.toggleFavoriteRequested(station))
                            },
                            onDelete: station.isCustom ? {
                                feature.send(.deleteCustomStationRequested(station.id))
                            } : nil,
                            onPlayPause: {
                                feature.send(.playPauseRequested(station))
                            },
                            onSelect: {
                                onSelectStation?(station)
                            }
                        )
                        .frame(width: 200)
                    }
                }
                .padding(.vertical, 4)
            }
            .hideScrollIndicatorsCompletely()
        }
    }

    // MARK: - Recently Played Section

    private var recentlyPlayedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.secondary)
                Text("Recently Played")
                    .font(.title3.bold())
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(state.recentStations) { station in
                        RadioStationCardView(
                            station: station,
                            isSelected: selectedStation?.id == station.id,
                            isCurrent: feature.isCurrent(station),
                            playbackState: feature.state(for: station),
                            isFavorite: state.isFavorite(station),
                            onToggleFavorite: {
                                feature.send(.toggleFavoriteRequested(station))
                            },
                            onDelete: station.isCustom ? {
                                feature.send(.deleteCustomStationRequested(station.id))
                            } : nil,
                            onPlayPause: {
                                feature.send(.playPauseRequested(station))
                            },
                            onSelect: {
                                onSelectStation?(station)
                            }
                        )
                        .frame(width: 200)
                    }
                }
                .padding(.vertical, 4)
            }
            .hideScrollIndicatorsCompletely()
        }
    }

    // MARK: - Hero Station

    private var featuredHeroStation: RadioStation? {
        guard state.searchQuery.isEmpty else { return nil }
        if state.selectedGenre == .all {
            return state.featuredStations.first
        } else {
            return state.featuredStations.first(where: { $0.genre == state.selectedGenre })
        }
    }

    private func featuredSection(_ station: RadioStation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Featured Broadcast")
                .font(.title3.bold())

            RadioHeroBannerView(
                station: station,
                isPlaying: feature.isPlaying,
                isCurrent: feature.isCurrent(station),
                onPlayPause: {
                    feature.send(.playPauseRequested(station))
                },
                onSelect: {
                    onSelectStation?(station)
                }
            )
        }
    }

    // MARK: - Stations Grid

    private var stationsGridSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                if state.selectedGenre == .all {
                    Text("All Stations")
                        .font(.title3.bold())
                } else {
                    Text("\(LocalizedStringKey(state.selectedGenre.rawValue)) Radio")
                        .font(.title3.bold())
                }

                Spacer()

                Text("\(state.stations.count) Stations")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if state.stations.isEmpty {
                ContentUnavailableView(
                    "No stations found",
                    systemImage: "dot.radiowaves.left.and.right",
                    description: Text("Please try selecting a different genre or adjusting search terms.")
                )
                .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(state.stations) { station in
                        RadioStationCardView(
                            station: station,
                            isSelected: selectedStation?.id == station.id,
                            isCurrent: feature.isCurrent(station),
                            playbackState: feature.state(for: station),
                            isFavorite: state.isFavorite(station),
                            onToggleFavorite: {
                                feature.send(.toggleFavoriteRequested(station))
                            },
                            onDelete: station.isCustom ? {
                                feature.send(.deleteCustomStationRequested(station.id))
                            } : nil,
                            onPlayPause: {
                                feature.send(.playPauseRequested(station))
                            },
                            onSelect: {
                                onSelectStation?(station)
                            }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Radio View · Standard") {
    let feature = MSRUPreviewData.makeRadioFeature()

    return RadioView(
        feature: feature,
        selectedStation: RadioStation.defaultStations[0],
        onSelectStation: { _ in }
    )
    .frame(width: 800, height: 700)
}

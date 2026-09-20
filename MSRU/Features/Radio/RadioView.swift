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
            LazyVStack(alignment: .leading, spacing: 24) {
                header
                genreFilterBar

                if let heroStation = featuredHeroStation {
                    featuredSection(heroStation)
                }

                stationsGridSection
            }
            .padding(28)
        }
        .task {
            feature.send(.appeared)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Radio")
                .font(.system(size: 32, weight: .bold))

            Text("Curated live internet radio stations with lossless and high-bitrate streaming.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
                            Text(genre.rawValue)
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
                Text(state.selectedGenre == .all ? "All Stations" : "\(state.selectedGenre.rawValue) Stations")
                    .font(.title3.bold())

                Spacer()

                Text("\(state.stations.count) stations")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if state.stations.isEmpty {
                ContentUnavailableView(
                    "No Radio Stations Found",
                    systemImage: "dot.radiowaves.left.and.right",
                    description: Text("Try selecting a different genre or adjusting your search terms.")
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

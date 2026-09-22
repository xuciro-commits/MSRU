//
//  RadioView.swift
//  MSRU
//

import SwiftUI
import Observation
import AppFoundation
import AppFoundationUI

// MARK: - Radio View

struct RadioView: View {

    let feature: FeatureHost<RadioFeature>
    var selectedStation: RadioStation? = nil
    var onSelectStation: ((RadioStation) -> Void)? = nil

    @Bindable private var state: RadioFeature.State
    @State private var isShowingAddStationSheet = false
    @State private var selectedStationIDs: Set<String> = []

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
        .overlay(alignment: .bottom) {
            if selectedStationIDs.count > 1 {
                floatingBatchBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedStationIDs.count)
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
                MarqueeSelectionContainer(selectedIDs: $selectedStationIDs) {
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(state.stations) { station in
                            RadioStationCardView(
                                station: station,
                                isSelected: selectedStationIDs.contains(station.id) || selectedStation?.id == station.id,
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
                                    SelectionHelper.handleTap(
                                        for: station.id,
                                        selectedIDs: $selectedStationIDs,
                                        allIDs: state.stations.map(\.id)
                                    )
                                    if selectedStationIDs.count == 1 {
                                        onSelectStation?(station)
                                    }
                                }
                            )
                            .marqueeItem(id: station.id)
                        }
                    }
                }
            }
        }
    }

    private var floatingBatchBar: some View {
        FloatingBatchBar(
            count: selectedStationIDs.count,
            title: "\(selectedStationIDs.count) stations",
            onDeselect: { selectedStationIDs.removeAll() }
        ) {
            Button {
                let selected = state.stations.filter { selectedStationIDs.contains($0.id) }
                for s in selected where !state.isFavorite(s) {
                    feature.send(.toggleFavoriteRequested(s))
                }
            } label: {
                Label("Favorite", systemImage: "heart.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button {
                let selected = state.stations.filter { selectedStationIDs.contains($0.id) }
                for s in selected where state.isFavorite(s) {
                    feature.send(.toggleFavoriteRequested(s))
                }
            } label: {
                Label("Unfavorite", systemImage: "heart.slash")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            let customCount = state.stations.filter { selectedStationIDs.contains($0.id) && $0.isCustom }.count
            if customCount > 0 {
                Button(role: .destructive) {
                    let selected = state.stations.filter { selectedStationIDs.contains($0.id) && $0.isCustom }
                    for s in selected {
                        feature.send(.deleteCustomStationRequested(s.id))
                    }
                    selectedStationIDs.removeAll()
                } label: {
                    Label("Delete (\(customCount))", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}

// MARK: - Radio Hero Banner View

struct RadioHeroBannerView: View {

    let station: RadioStation
    let isPlaying: Bool
    let isCurrent: Bool
    let onPlayPause: () -> Void
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .bottomLeading) {
                // Background artistic gradient
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: bannerColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                    )

                // Background subtle decorative pattern
                HStack {
                    Spacer()
                    Image(systemName: station.genre.systemImage)
                        .font(.system(size: 140, weight: .ultraLight))
                        .foregroundStyle(.white.opacity(0.12))
                        .offset(x: 20, y: 10)
                }
                .clipped()

                // Content
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        // LIVE Badge
                        HStack(spacing: 5) {
                            Circle()
                                .fill(isCurrent && isPlaying ? Color.red : Color.white)
                                .frame(width: 7, height: 7)
                            Text("Featured Live")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.0)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())

                        Text(LocalizedStringKey(station.genre.rawValue))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.2))
                            .clipShape(Capsule())

                        Spacer()

                        if let bitrate = station.bitrateKbps {
                            Text("\(bitrate) kbps • \(station.codec)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(station.name)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(station.description)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.white.opacity(0.88))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    HStack(spacing: 12) {
                        Button(action: onPlayPause) {
                            HStack(spacing: 8) {
                                Image(systemName: isCurrent && isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                Text(LocalizedStringKey(isCurrent && isPlaying ? "Pause Stream" : "Listen Now"))
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                        }
                        .buttonStyle(.plain)

                        Text("\(station.country) • \(station.language)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
                .padding(22)
            }
            .frame(height: 190)
            .shadow(color: .black.opacity(isHovered ? 0.2 : 0.08), radius: isHovered ? 12 : 6, y: isHovered ? 6 : 3)
            .scaleEffect(isHovered ? 1.008 : 1.0)
            .animation(.easeOut(duration: 0.2), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var bannerColors: [Color] {
        switch station.genre {
        case .indie:
            return [Color(red: 0.15, green: 0.35, blue: 0.45), Color(red: 0.08, green: 0.18, blue: 0.28)]
        case .electronic:
            return [Color(red: 0.35, green: 0.12, blue: 0.48), Color(red: 0.12, green: 0.08, blue: 0.32)]
        case .classical:
            return [Color(red: 0.48, green: 0.28, blue: 0.12), Color(red: 0.24, green: 0.12, blue: 0.06)]
        case .jazz:
            return [Color(red: 0.18, green: 0.32, blue: 0.28), Color(red: 0.08, green: 0.16, blue: 0.14)]
        case .pop:
            return [Color(red: 0.52, green: 0.15, blue: 0.32), Color(red: 0.28, green: 0.08, blue: 0.18)]
        case .ambient:
            return [Color(red: 0.12, green: 0.22, blue: 0.38), Color(red: 0.05, green: 0.10, blue: 0.20)]
        case .all:
            return [Color(red: 0.22, green: 0.24, blue: 0.35), Color(red: 0.10, green: 0.11, blue: 0.18)]
        }
    }
}

// MARK: - Radio Station Card View

struct RadioStationCardView: View {

    let station: RadioStation
    let isSelected: Bool
    let isCurrent: Bool
    let playbackState: TrackPlaybackState
    var isFavorite: Bool = false
    var onToggleFavorite: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    let onPlayPause: () -> Void
    let onSelect: () -> Void

    @State private var isHovered = false

    private var isPlaying: Bool {
        isCurrent && playbackState.isPlaying
    }

    private var isResolving: Bool {
        isCurrent && playbackState.isResolving
    }

    var body: some View {
        FoundationCard(
            aspectRatio: 16.0 / 11.0,
            cornerRadius: 12,
            isSelected: isSelected,
            onSelect: onSelect
        ) {
            // Media Area
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: cardGradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                    )

                Image(systemName: station.genre.systemImage)
                    .font(.system(size: 56, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.18))
            }
        } topLeadingBadges: {
            if station.isCustom {
                FoundationCardBadge("Custom", foregroundStyle: .white, backgroundStyle: Color.blue.opacity(0.85))
            }
        } topTrailingBadges: {
            HStack(spacing: 6) {
                Button {
                    onToggleFavorite?()
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isFavorite ? Color.red : Color.white.opacity(0.85))
                        .padding(5)
                        .background(.black.opacity(0.45), in: Circle())
                }
                .buttonStyle(.plain)
                .help(isFavorite ? "Remove from Favorites" : "Add to Favorites")

                FoundationCardBadge(
                    "Live",
                    systemImage: "circle.fill",
                    foregroundStyle: .white,
                    backgroundStyle: isPlaying ? Color.red : Color.black.opacity(0.45)
                )
            }
        } actionOverlay: {
            if isResolving {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(.ultraThinMaterial))
            } else {
                FoundationCardActionButton(
                    systemImage: isPlaying ? "pause.fill" : "play.fill",
                    action: onPlayPause
                )
            }
        } title: {
            Text(station.name)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
        } subtitle: {
            Text(station.description)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(height: 28, alignment: .topLeading)
        } footer: {
            HStack(spacing: 6) {
                Text(LocalizedStringKey(station.genre.rawValue))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Capsule())

                Spacer()

                Text(station.country)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .contextMenu {
            Button(isPlaying ? "Pause" : "Play") {
                onPlayPause()
            }
            Button(isFavorite ? "Remove from Favorites" : "Favorite") {
                onToggleFavorite?()
            }
            if station.isCustom, let onDelete {
                Divider()
                Button(role: .destructive, action: onDelete) {
                    Label("Delete Custom Station", systemImage: "trash")
                }
            }
        }
    }

    private var cardGradientColors: [Color] {
        switch station.genre {
        case .indie:
            return [Color(red: 0.16, green: 0.38, blue: 0.48), Color(red: 0.09, green: 0.20, blue: 0.28)]
        case .electronic:
            return [Color(red: 0.40, green: 0.15, blue: 0.52), Color(red: 0.15, green: 0.08, blue: 0.35)]
        case .classical:
            return [Color(red: 0.52, green: 0.30, blue: 0.14), Color(red: 0.26, green: 0.14, blue: 0.07)]
        case .jazz:
            return [Color(red: 0.20, green: 0.36, blue: 0.30), Color(red: 0.09, green: 0.18, blue: 0.15)]
        case .pop:
            return [Color(red: 0.56, green: 0.18, blue: 0.35), Color(red: 0.30, green: 0.09, blue: 0.20)]
        case .ambient:
            return [Color(red: 0.15, green: 0.25, blue: 0.42), Color(red: 0.06, green: 0.12, blue: 0.22)]
        case .all:
            return [Color(red: 0.25, green: 0.27, blue: 0.38), Color(red: 0.12, green: 0.13, blue: 0.20)]
        }
    }
}

// MARK: - Add Station Sheet View

struct AddStationSheetView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var streamURLString: String = ""
    @State private var genre: RadioGenre = .classical
    @State private var country: String = "Global"
    @State private var descriptionText: String = ""
    @State private var errorMessage: String? = nil

    let onSave: (RadioStation) -> Void

    private var isValidURL: Bool {
        guard let url = URL(string: streamURLString.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return false
        }
        return true
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isValidURL
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Station Details") {
                    TextField("Station Name", text: $name, prompt: Text("e.g. My Favorite Station"))

                    TextField("Stream URL", text: $streamURLString, prompt: Text("https://example.com/stream.mp3"))
                        #if os(iOS)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        #endif

                    if !streamURLString.isEmpty && !isValidURL {
                        Text("Please enter a valid HTTP or HTTPS stream URL.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Picker("Genre", selection: $genre) {
                        ForEach(RadioGenre.allCases.filter { $0 != .all }) { item in
                            Text(LocalizedStringKey(item.rawValue)).tag(item)
                        }
                    }

                    TextField("Country/Region", text: $country, prompt: Text("e.g. Global, China, USA"))
                    TextField("Description (Optional)", text: $descriptionText, prompt: Text("Optional notes or tagline"))
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Custom Station")
            #if os(macOS)
            .frame(minWidth: 420, minHeight: 340)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        guard canSave,
              let url = URL(string: streamURLString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            errorMessage = "Invalid stream URL or missing station name."
            return
        }

        let newStation = RadioStation(
            id: "custom-\(UUID().uuidString.prefix(8).lowercased())",
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "User-added custom stream."
                : descriptionText.trimmingCharacters(in: .whitespacesAndNewlines),
            genre: genre,
            streamURL: url,
            country: country.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Global"
                : country.trimmingCharacters(in: .whitespacesAndNewlines),
            isFeatured: false,
            isCustom: true
        )

        onSave(newStation)
        dismiss()
    }
}

// MARK: - Previews

#Preview("Radio View · Standard") {
    let feature = MSRUPreviewData.makeRadioFeature()

    return RadioView(
        feature: feature,
        selectedStation: RadioStation.defaultStations[0],
        onSelectStation: { _ in }
    )
    .frame(width: 800, height: 700)
}

#Preview("Radio Hero Banner") {
    let station = RadioStation.defaultStations[0]
    return RadioHeroBannerView(
        station: station,
        isPlaying: true,
        isCurrent: true,
        onPlayPause: {},
        onSelect: {}
    )
    .padding(28)
    .frame(width: 680)
}

#Preview("Radio Station Card") {
    let station = RadioStation.defaultStations[1]
    return RadioStationCardView(
        station: station,
        isSelected: true,
        isCurrent: true,
        playbackState: .playing,
        isFavorite: true,
        onToggleFavorite: {},
        onPlayPause: {},
        onSelect: {}
    )
    .frame(width: 220)
    .padding(20)
}

#Preview("Add Station Sheet") {
    AddStationSheetView(onSave: { _ in })
}

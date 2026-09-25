//
//  ListenNowView.swift
//  MSRU
//
//  Apple Music-styled Home (主页) surface.
//  Backed by real SQLite listening behavior (Recently Played, Added, Frequently Played, Favorites).
//  Features edge-to-edge continuous scrolling under sidebar/inspector panels with translucent chevrons.
//

import SwiftUI
import Observation
import AppFoundation
import AppFoundationUI
import MusicLibrary
import MusicPlayback

// MARK: - Presentation Types

typealias HomeView = ListenNowView
typealias HomeFeature = ListenNowFeature

// MARK: - Home View

struct ListenNowView: View {
    var playback: PlaybackController? = nil
    let onSelect: (MusicContent) -> Void

    @State private var snapshot = ListenNowBehaviorSnapshot()
    @State private var isLoading = true

    @Environment(\.workspaceSafeAreaInsets)
    private var workspaceSafeArea

    init(
        playback: PlaybackController? = nil,
        onSelect: @escaping (MusicContent) -> Void
    ) {
        self.playback = playback
        self.onSelect = onSelect
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 32) {
                header
                    .padding(.horizontal, 28)
                    .padding(.top, 28)

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if snapshot.totalTrackCount == 0 && snapshot.recentlyPlayed.isEmpty {
                    emptyLibraryWelcome
                } else {
                    recentlyPlayedSection

                    if !snapshot.favorites.isEmpty {
                        favoritesSection
                    }

                    if !snapshot.frequentlyPlayed.isEmpty {
                        heavyRotationSection
                    }

                    if !snapshot.recentlyAdded.isEmpty {
                        recentlyAddedSection
                    }

                    listeningStatsSection
                        .padding(.horizontal, 28)
                }
            }
            .padding(.bottom, 60)
        }
        .hideScrollIndicatorsCompletely()
        .task {
            await loadData(initial: true)
        }
        .onAppear {
            Task {
                await loadData()
            }
        }
        .onChange(of: playback?.currentItem?.id) { _, _ in
            Task {
                try? await Task.sleep(nanoseconds: 200_000_000)
                await loadData()
            }
        }
        .refreshable {
            await loadData()
        }
    }

    private func loadData(initial: Bool = false) async {
        if initial && snapshot.recentlyPlayed.isEmpty {
            isLoading = true
        }
        do {
            snapshot = try await LibraryQueryEngine.shared.fetchBehaviorSnapshot()
        } catch {
            print("[HomeView] Failed to fetch behavior snapshot: \(error)")
        }
        isLoading = false
    }

    // MARK: - Empty Library Welcome

    private var emptyLibraryWelcome: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.house")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Welcome to MSRU")
                .font(.title2.bold())
            Text("Add music from your folders, a NAS or Subsonic server, or Apple Music.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.quaternary.opacity(0.5))
        )
        .padding(.horizontal, 28)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey("Home"))
                    .font(.system(size: 34, weight: .bold))
            }

            Spacer()
        }
    }

    // MARK: - Shelves

    @ViewBuilder
    private var recentlyPlayedSection: some View {
        if !snapshot.recentlyPlayed.isEmpty {
            trackShelf(String(localized: "Recently Played"), snapshot.recentlyPlayed)
        }
    }

    private var favoritesSection: some View {
        trackShelf(String(localized: "Favorites"), snapshot.favorites)
    }

    private var heavyRotationSection: some View {
        trackShelf(String(localized: "Heavy Rotation"), snapshot.frequentlyPlayed)
    }

    private var recentlyAddedSection: some View {
        trackShelf(String(localized: "Recently Added"), snapshot.recentlyAdded)
    }

    /// A shelf of tracks; choosing one plays the shelf from that track.
    private func trackShelf(_ title: String, _ tracks: [TrackRowSummary]) -> some View {
        ContinuousShelfView(
            title: title,
            hasChevronHeader: true,
            items: tracks,
            spacing: 16,
            leadingInset: 28,
            pageSize: 4
        ) { item in
            squareTrackCard(item, in: tracks)
        }
    }

    private func squareTrackCard(_ item: TrackRowSummary, in tracks: [TrackRowSummary]) -> some View {
        Button {
            guard let playback else { return }
            let queue = tracks.map { PlaybackItem(summary: $0) }
            let start = tracks.firstIndex { $0.id == item.id } ?? 0
            playback.play(queue[start], context: queue)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                MediaImageView(
                    reference: item.artworkReference,
                    thumbnailPixelSize: CGSize(width: 320, height: 320),
                    placeholderSystemImage: "music.note",
                    cornerRadius: 12
                )
                .frame(width: 160, height: 160)
                .shadow(color: .black.opacity(0.18), radius: 8, y: 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(item.artist)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(width: 160, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Listening Overview

    private var listeningStatsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Listening Overview")
                .font(.title3.bold())

            HStack(spacing: 18) {
                statCard(
                    title: "Songs",
                    value: snapshot.totalTrackCount,
                    caption: "In your library",
                    systemImage: "music.note.list",
                    color: .accentColor
                )

                statCard(
                    title: "Favorites",
                    value: snapshot.favorites.count,
                    caption: "Marked as favorite",
                    systemImage: "heart.fill",
                    color: .red
                )

                statCard(
                    title: "Heavy Rotation",
                    value: snapshot.frequentlyPlayed.count,
                    caption: "Most played",
                    systemImage: "repeat",
                    color: .purple
                )
            }
        }
    }

    private func statCard(
        title: LocalizedStringKey,
        value: Int,
        caption: LocalizedStringKey,
        systemImage: String,
        color: Color
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 26))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value, format: .number)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)

                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.quaternary)
        )
    }
}

// MARK: - Feature

enum ListenNowFeature: ApplicationFeaturePresentation {
    typealias Route = SceneRoute
    typealias PresentationContext = SceneModel

    nonisolated static var contributions: FeatureContribution<Route> {
        FeatureContribution(
            sidebar: [
                SidebarContribution(
                    id: "home",
                    group: "Discover",
                    title: "Home",
                    systemImage: "house.fill",
                    route: .section(.listenNow),
                    order: 10
                )
            ],
            routes: [
                RouteContribution(
                    id: "listen-now",
                    route: .section(.listenNow)
                )
            ]
        )
    }

    @MainActor
    static var routeDestinations: [RouteDestination<Route, PresentationContext>] {
        [
            RouteDestination(
                id: "listen-now",
                route: .section(.listenNow)
            ) { scene in
                ListenNowView(
                    playback: scene.application.playback,
                    onSelect: { item in
                        scene.selectedMusicContent = item
                    }
                )
            }
        ]
    }
}

// MARK: - Preview

#Preview("Home") {
    ListenNowView(
        onSelect: { _ in }
    )
    .frame(width: 1100, height: 800)
}

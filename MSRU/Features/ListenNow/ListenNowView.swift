//
//  ListenNowView.swift
//  MSRU
//
//  User-centric personalized home surface.
//  Backed strictly by real SQLite listening behavior (Recently Played, Added, Frequently Played, Favorites).
//

import SwiftUI
import Observation
import AppFoundation
import AppFoundationUI

struct ListenNowView: View {
    @Bindable var store: MusicCatalogStore
    var playback: PlaybackController? = nil
    let onSelect: (MusicContent) -> Void

    @State private var snapshot = ListenNowBehaviorSnapshot()
    @State private var isLoading = true

    @Environment(\.workspaceSafeAreaInsets)
    private var workspaceSafeArea

    init(
        store: MusicCatalogStore,
        playback: PlaybackController? = nil,
        onSelect: @escaping (MusicContent) -> Void
    ) {
        self.store = store
        self.playback = playback
        self.onSelect = onSelect
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 32) {
                header

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if snapshot.recentlyPlayed.isEmpty && snapshot.recentlyAdded.isEmpty && snapshot.favorites.isEmpty {
                    emptyHomeState
                } else {
                    if let hero = snapshot.heroItem {
                        heroCard(hero)
                    }

                    if !snapshot.recentlyPlayed.isEmpty {
                        shelfSection(title: "Recently Played", systemImage: "clock.arrow.circlepath", items: snapshot.recentlyPlayed)
                    }

                    if !snapshot.recentlyAdded.isEmpty {
                        shelfSection(title: "Recently Added", systemImage: "sparkles", items: snapshot.recentlyAdded)
                    }

                    if !snapshot.frequentlyPlayed.isEmpty {
                        shelfSection(title: "Heavy Rotation", systemImage: "repeat", items: snapshot.frequentlyPlayed)
                    }

                    if !snapshot.favorites.isEmpty {
                        shelfSection(title: "Favorites", systemImage: "heart.fill", items: snapshot.favorites)
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .hideScrollIndicatorsCompletely()
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
    }

    private func loadData() async {
        isLoading = true
        do {
            snapshot = try await LibraryQueryEngine.shared.fetchBehaviorSnapshot()
        } catch {
            print("[ListenNowView] Failed to fetch behavior snapshot: \(error)")
        }
        isLoading = false
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Listen Now")
                    .font(.largeTitle.bold())

                Text("Your personal music hub, shaped by your listening habits.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.top, 28)
    }

    // MARK: - Hero Card

    private func heroCard(_ item: TrackRowSummary) -> some View {
        HStack(spacing: 24) {
            MediaImageView(
                reference: item.artworkReference,
                thumbnailPixelSize: CGSize(width: 320, height: 320),
                placeholderSystemImage: "music.note",
                cornerRadius: 16
            )
            .frame(width: 140, height: 140)
            .shadow(color: .black.opacity(0.18), radius: 12, y: 6)

            VStack(alignment: .leading, spacing: 8) {
                Text("RECOMMENDED FROM YOUR LIBRARY")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .tracking(1)

                Text(item.title)
                    .font(.title2.bold())
                    .lineLimit(1)

                Text(item.artist)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let album = item.album {
                    Text(album)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                HStack(spacing: 12) {
                    Button {
                        // Play hero item
                        if let playback {
                            playback.play(PlaybackItem(summary: item))
                        }
                    } label: {
                        Label("Play Now", systemImage: "play.fill")
                            .font(.callout.bold())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)

                    if let format = item.format {
                        Text(format)
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(.quaternary))
                    }

                    if let source = item.sourceDisplayName {
                        Text(source)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
            }

            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.12), Color.primary.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .padding(.horizontal, 28)
    }

    // MARK: - Shelves

    private func shelfSection(title: String, systemImage: String, items: [TrackRowSummary]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(Color.accentColor)
                Text(title)
                    .font(.title3.bold())
            }
            .padding(.horizontal, 28)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(items) { item in
                        shelfCard(item)
                    }
                }
                .padding(.horizontal, 28)
            }
        }
    }

    private func shelfCard(_ item: TrackRowSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            MediaImageView(
                reference: item.artworkReference,
                thumbnailPixelSize: CGSize(width: 240, height: 240),
                placeholderSystemImage: "music.note",
                cornerRadius: 12
            )
            .frame(width: 140, height: 140)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)

                Text(item.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 140, alignment: .leading)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if let playback {
                playback.play(PlaybackItem(summary: item))
            }
        }
    }

    // MARK: - Empty State

    private var emptyHomeState: some View {
        ContentUnavailableView {
            Label("Welcome to Listen Now", systemImage: "music.note.house")
        } description: {
            Text("Play songs from your library or connected NAS to generate personalized recents, heavy rotation, and favorites.")
        }
        .frame(maxWidth: .infinity, minHeight: 280)
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
                    id: "listen-now",
                    group: "Discover",
                    title: "Listen Now",
                    systemImage: "play.circle",
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
                    store: scene.application.musicCatalog,
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

#Preview("Listen Now") {
    ListenNowView(
        store: MSRUPreviewData.makeCatalogStore(),
        onSelect: { _ in }
    )
    .frame(width: 1100, height: 800)
}

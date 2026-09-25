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
                    // 1. 专属精选推荐 (Top Picks)
                    topPicksSection

                    // 2. 最近播放 (Recently Played)
                    recentlyPlayedSection

                    // 3. 为你打造 (Made for You)
                    madeForYouSection

                    // 4. 常听经典 (Heavy Rotation)
                    if !snapshot.frequentlyPlayed.isEmpty {
                        heavyRotationSection
                    }

                    // 5. 最近添加 (Recently Added)
                    if !snapshot.recentlyAdded.isEmpty {
                        recentlyAddedSection
                    }

                    // 6. 听歌回忆与里程碑 (Replay / Stats)
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
            Text("欢迎来到 MSRU")
                .font(.title2.bold())
            Text("在这里探索你的音乐世界。你可以从本地目录、极空间 NAS 或 Apple Music 导入曲库。")
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

    // MARK: - 1. 专属精选推荐 (Top Picks)

    private struct TopPickItem: Identifiable {
        let id: String
        let eyebrow: String
        let title: String
        let subtitle: String?
        let gradientColors: [Color]
        let iconName: String
        let isArtistFocus: Bool
        let artistName: String?
    }

    private var topPickItems: [TopPickItem] {
        let heroArtist = snapshot.heroItem?.artist ?? String(localized: "Personal Mix")
        return [
            TopPickItem(
                id: "artist-focus",
                eyebrow: "专享内容",
                title: "关注的艺人",
                subtitle: heroArtist,
                gradientColors: [Color(red: 0.65, green: 0.42, blue: 0.18), Color(red: 0.28, green: 0.16, blue: 0.08)],
                iconName: "person.crop.circle.fill",
                isArtistFocus: true,
                artistName: heroArtist
            ),
            TopPickItem(
                id: "discovery-station",
                eyebrow: "专属推荐",
                title: "探索电台",
                subtitle: "发现更多你可能会喜欢的歌曲与艺人",
                gradientColors: [Color(red: 0.12, green: 0.65, blue: 0.65), Color(red: 0.38, green: 0.15, blue: 0.65)],
                iconName: "apple.logo",
                isArtistFocus: false,
                artistName: nil
            ),
            TopPickItem(
                id: "chill-mix",
                eyebrow: "专属心情好歌",
                title: "乐享悠闲",
                subtitle: "随舒缓音律来一次深呼吸，放松身心。",
                gradientColors: [Color(red: 0.18, green: 0.58, blue: 0.95), Color(red: 0.08, green: 0.28, blue: 0.62)],
                iconName: "apple.logo",
                isArtistFocus: false,
                artistName: nil
            ),
            TopPickItem(
                id: "personal-station",
                eyebrow: "专属推荐",
                title: "\(heroArtist)的电台",
                subtitle: "专属个人定制流媒体，无限畅听",
                gradientColors: [Color(red: 0.95, green: 0.35, blue: 0.32), Color(red: 0.78, green: 0.08, blue: 0.22)],
                iconName: "apple.logo",
                isArtistFocus: false,
                artistName: nil
            )
        ]
    }

    private var topPicksSection: some View {
        ContinuousShelfView(
            title: "专属精选推荐",
            hasChevronHeader: false,
            items: topPickItems,
            spacing: 18,
            leadingInset: 28,
            pageSize: 3
        ) { item in
            topPickCard(item)
        }
    }

    private func topPickCard(_ item: TopPickItem) -> some View {
        Button {
            guard let playback else { return }
            switch item.id {
            case "artist-focus":
                if let hero = snapshot.heroItem {
                    let artistTracks = (snapshot.recentlyPlayed + snapshot.frequentlyPlayed + snapshot.favorites + snapshot.recentlyAdded)
                        .filter { $0.artist.localizedCaseInsensitiveCompare(hero.artist) == .orderedSame }
                    let uniqueTracks = Array(NSOrderedSet(array: artistTracks)).compactMap { $0 as? TrackRowSummary }
                    let items = (uniqueTracks.isEmpty ? [hero] : uniqueTracks).map { PlaybackItem(summary: $0) }
                    playback.play(items[0], context: items)
                }
            case "discovery-station":
                let tracks = snapshot.recentlyAdded.shuffled()
                if let first = tracks.first {
                    let items = tracks.map { PlaybackItem(summary: $0) }
                    playback.play(items[0], context: items)
                }
            case "chill-mix":
                let tracks = snapshot.recentlyPlayed
                if let first = tracks.first {
                    let items = tracks.map { PlaybackItem(summary: $0) }
                    playback.play(items[0], context: items)
                }
            case "personal-station":
                let tracks = (snapshot.frequentlyPlayed + snapshot.favorites)
                if let first = tracks.first {
                    let items = tracks.map { PlaybackItem(summary: $0) }
                    playback.play(items[0], context: items)
                } else if let hero = snapshot.heroItem {
                    playback.play(PlaybackItem(summary: hero))
                }
            default:
                if let hero = snapshot.heroItem {
                    playback.play(PlaybackItem(summary: hero))
                }
            }
        } label: {
            ZStack(alignment: .bottomLeading) {
                // Background Gradient
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: item.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                    )

                // Artistic Graphic in Center
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 3) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 13, weight: .bold))
                            Text("Music")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(14)
                    }

                    Spacer()

                    if item.isArtistFocus {
                        artistCollageView
                    } else if item.id == "chill-mix" {
                        zenStonesGraphic
                    } else if item.id == "discovery-station" {
                        geometricRayGraphic
                    } else {
                        origamiChevronGraphic
                    }

                    Spacer()
                }

                // Text Overlay at Bottom
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.eyebrow)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))

                    Text(item.title)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(2)
                    }
                }
                .padding(16)
            }
            .frame(width: 220, height: 280)
            .shadow(color: .black.opacity(0.22), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
    }

    // Artistic graphics
    private var artistCollageView: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 90, height: 90)
                .offset(x: -24, y: -16)
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 76, height: 76)
                .offset(x: 28, y: 12)
            Image(systemName: "person.2.fill")
                .font(.system(size: 38))
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(height: 110)
    }

    private var zenStonesGraphic: some View {
        VStack(spacing: 8) {
            Capsule()
                .stroke(Color.white.opacity(0.55), lineWidth: 2)
                .frame(width: 60, height: 24)
            Capsule()
                .stroke(Color.white.opacity(0.55), lineWidth: 2)
                .frame(width: 90, height: 32)
            Capsule()
                .stroke(Color.white.opacity(0.55), lineWidth: 2)
                .frame(width: 120, height: 40)
        }
        .frame(height: 110)
    }

    private var geometricRayGraphic: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 120, height: 120)
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(.white.opacity(0.75))
        }
        .frame(height: 110)
    }

    private var origamiChevronGraphic: some View {
        ZStack {
            Image(systemName: "chevron.right.2")
                .font(.system(size: 52, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(height: 110)
    }

    // MARK: - 2. 最近播放 (Recently Played)

    @ViewBuilder
    private var recentlyPlayedSection: some View {
        if !snapshot.recentlyPlayed.isEmpty {
            ContinuousShelfView(
                title: "最近播放",
                hasChevronHeader: true,
                items: snapshot.recentlyPlayed,
                spacing: 16,
                leadingInset: 28,
                pageSize: 4
            ) { item in
                squareTrackCard(item)
            }
        }
    }

    private func squareTrackCard(_ item: TrackRowSummary) -> some View {
        Button {
            if let playback {
                playback.play(PlaybackItem(summary: item))
            }
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

    // MARK: - 3. 为你打造 (Made for You)

    private struct MixItem: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let systemImage: String
        let gradient: LinearGradient
    }

    private let madeForYouMixes: [MixItem] = [
        MixItem(
            id: "favorites-mix",
            title: "喜爱精选",
            subtitle: "每周更新你最爱的音乐",
            systemImage: "heart.fill",
            gradient: LinearGradient(colors: [Color.pink, Color.red], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        MixItem(
            id: "chill-mix",
            title: "轻松时光",
            subtitle: "适合放松与思绪慢行的音律",
            systemImage: "moon.stars.fill",
            gradient: LinearGradient(colors: [Color.teal, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        MixItem(
            id: "heavy-rotation-mix",
            title: "常听经典",
            subtitle: "陪伴你时间最长的旋律",
            systemImage: "repeat",
            gradient: LinearGradient(colors: [Color.indigo, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        MixItem(
            id: "discovery-station",
            title: "发现电台",
            subtitle: "拓展你的听歌风格与边界",
            systemImage: "sparkles",
            gradient: LinearGradient(colors: [Color.orange, Color.yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    ]

    private func playMix(_ mix: MixItem) {
        guard let playback else { return }
        let queue: [TrackRowSummary] = switch mix.id {
        case "favorites-mix": snapshot.favorites
        case "heavy-rotation-mix": snapshot.frequentlyPlayed
        case "chill-mix": snapshot.recentlyPlayed
        default: snapshot.recentlyAdded
        }
        if let first = queue.first {
            let items = queue.map { PlaybackItem(summary: $0) }
            playback.play(items[0], context: items)
        } else if let hero = snapshot.heroItem {
            playback.play(PlaybackItem(summary: hero))
        }
    }

    private var madeForYouSection: some View {
        ContinuousShelfView(
            title: "为你打造",
            hasChevronHeader: true,
            items: madeForYouMixes,
            spacing: 16,
            leadingInset: 28,
            pageSize: 4
        ) { mix in
            Button {
                playMix(mix)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    ZStack(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(mix.gradient)
                            .frame(width: 160, height: 160)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                            )
                            .shadow(color: .black.opacity(0.18), radius: 8, y: 4)

                        VStack(alignment: .leading) {
                            Image(systemName: mix.systemImage)
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(12)

                            Spacer()

                            Text(mix.title)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(12)
                        }
                    }

                    Text(mix.subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(width: 160, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 4. 常听经典 (Heavy Rotation)

    private var heavyRotationSection: some View {
        ContinuousShelfView(
            title: "常听经典",
            hasChevronHeader: true,
            items: snapshot.frequentlyPlayed,
            spacing: 16,
            leadingInset: 28,
            pageSize: 4
        ) { item in
            squareTrackCard(item)
        }
    }

    // MARK: - 5. 最近添加 (Recently Added)

    private var recentlyAddedSection: some View {
        ContinuousShelfView(
            title: "最近添加",
            hasChevronHeader: true,
            items: snapshot.recentlyAdded,
            spacing: 16,
            leadingInset: 28,
            pageSize: 4
        ) { item in
            squareTrackCard(item)
        }
    }

    // MARK: - 6. 听歌回忆与里程碑 (Replay / Stats)

    private var listeningStatsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("收听概况与回忆")
                .font(.title3.bold())

            HStack(spacing: 18) {
                statCard(
                    title: "已收录曲目",
                    value: "\(snapshot.totalTrackCount)",
                    caption: "本地曲库",
                    systemImage: "music.note.list",
                    color: .accentColor
                )

                statCard(
                    title: "特别喜爱",
                    value: "\(snapshot.favorites.count)",
                    caption: "红心标记歌曲",
                    systemImage: "heart.fill",
                    color: .red
                )

                statCard(
                    title: "重度循环",
                    value: "\(snapshot.frequentlyPlayed.count)",
                    caption: "最高频常听",
                    systemImage: "repeat",
                    color: .purple
                )
            }
        }
    }

    private func statCard(title: String, value: String, caption: String, systemImage: String, color: Color) -> some View {
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

                Text(value)
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

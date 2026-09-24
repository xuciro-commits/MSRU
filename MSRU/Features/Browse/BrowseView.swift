//
//  BrowseView.swift
//  MSRU
//
//  Apple Music-styled Browse (新发现 / 浏览) surface.
//  Features edge-to-edge continuous scrolling under sidebar/inspector panels with translucent chevrons.
//  Includes Artist Sharing (16:9), Apple Music Sessions, Club DJ Mixes, 3-Row New Tracks, and Genre Tiles.
//

import SwiftUI
import Observation
import AppFoundation
import AppFoundationUI
import MusicLibrary

struct BrowseView: View {

    let feature: FeatureHost<BrowseFeature>

    @Bindable
    private var state: BrowseFeature.State

    private let gridColumns = [
        GridItem(.adaptive(minimum: 220, maximum: 300), spacing: 18)
    ]

    // MARK: - Init

    init(feature: FeatureHost<BrowseFeature>) {
        self.feature = feature
        self._state = Bindable(wrappedValue: feature.state)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 32) {
                header
                    .padding(.horizontal, 28)
                    .padding(.top, 28)

                sourceSummary
                    .padding(.horizontal, 28)

                if let error = feature.libraryErrorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .padding(.horizontal, 28)
                }

                // 1. 观看艺人分享 > (Artist Sharing 16:9 Shelf)
                artistSharingSection

                // 2. Apple Music Sessions > (Studio Sessions Shelf)
                appleMusicSessionsSection

                // 3. Club DJ 混音精选 > (Club DJ Mixes Shelf)
                clubDJMixesSection

                // 4. 最新发布与精选单曲 (New Music 3-Row Grid)
                newReleasesSection

                // 5. 探索流派与分类 (Explore by Genre Colorful Tiles)
                exploreGenreTilesSection
                    .padding(.horizontal, 28)

                // 6. Openverse 实时搜索结果
                openverseResultsSection
                    .padding(.horizontal, 28)
            }
            .padding(.bottom, 60)
        }
        .hideScrollIndicatorsCompletely()
        .task {
            feature.send(.appeared)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey("Browse"))
                    .font(.system(size: 34, weight: .bold))

                Text("探索全球潮流企划、现场录音室与开放版权音频。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Label("Openverse 驱动", systemImage: "globe")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Provider Summary

    private var sourceSummary: some View {
        HStack(spacing: 14) {
            Image(systemName: "globe")
                .font(.title2)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text("Openverse 全球音频库")
                    .font(.headline)

                Text("开放版权 · 封面抓取 · 授权元数据 · 在线试听与无损入库")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("流媒体与入库")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(
            .quaternary,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    // MARK: - 1. 观看艺人分享 (16:9 Widescreen Shelf)

    private struct ArtistVideoItem: Identifiable {
        let id: String
        let title: String
        let artist: String
        let gradient: LinearGradient
    }

    private let artistVideos: [ArtistVideoItem] = [
        ArtistVideoItem(
            id: "v-1",
            title: "Malie Donn on The Golden Child",
            artist: "Malie Donn",
            gradient: LinearGradient(colors: [Color.red.opacity(0.8), Color.black], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        ArtistVideoItem(
            id: "v-2",
            title: "AZ Chike: The Ebro Show [E]",
            artist: "AZ Chike & Ebro Darden",
            gradient: LinearGradient(colors: [Color.indigo.opacity(0.8), Color.purple.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        ArtistVideoItem(
            id: "v-3",
            title: "Jackson Wang says 'THANK YOU'",
            artist: "Jackson Wang",
            gradient: LinearGradient(colors: [Color.orange.opacity(0.8), Color.black], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        ArtistVideoItem(
            id: "v-4",
            title: "ROSÉ teaches us her new trick!",
            artist: "ROSÉ",
            gradient: LinearGradient(colors: [Color.pink.opacity(0.8), Color.purple.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        ArtistVideoItem(
            id: "v-5",
            title: "Miley: Endless Summer Vacation",
            artist: "Miley Cyrus",
            gradient: LinearGradient(colors: [Color.blue.opacity(0.8), Color.teal.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    ]

    private var artistSharingSection: some View {
        ContinuousShelfView(
            title: "观看艺人分享",
            hasChevronHeader: true,
            items: artistVideos,
            spacing: 16,
            leadingInset: 28,
            pageSize: 3
        ) { item in
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(item.gradient)
                        .frame(width: 250, height: 140)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                        )

                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(.white.opacity(0.85))
                                .padding(10)
                        }
                        Spacer()
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(item.artist)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(width: 250, alignment: .leading)
            }
        }
    }

    // MARK: - 2. Apple Music Sessions (Studio Sessions Shelf)

    private struct SessionItem: Identifiable {
        let id: String
        let title: String
        let artist: String
        let subtitle: String
        let gradient: LinearGradient
    }

    private let sessionItems: [SessionItem] = [
        SessionItem(
            id: "s-1",
            title: "Evil Island",
            artist: "Sessions",
            subtitle: "Evil Island [E]",
            gradient: LinearGradient(colors: [Color(red: 0.2, green: 0.35, blue: 0.5), Color.black], startPoint: .top, endPoint: .bottom)
        ),
        SessionItem(
            id: "s-2",
            title: "Kim Burrell",
            artist: "Sessions",
            subtitle: "Everywhere You Go (Apple Music...)",
            gradient: LinearGradient(colors: [Color(red: 0.55, green: 0.4, blue: 0.2), Color.black], startPoint: .top, endPoint: .bottom)
        ),
        SessionItem(
            id: "s-3",
            title: "XCOMM",
            artist: "Sessions",
            subtitle: "Sessions [E]",
            gradient: LinearGradient(colors: [Color(red: 0.45, green: 0.2, blue: 0.35), Color.black], startPoint: .top, endPoint: .bottom)
        ),
        SessionItem(
            id: "s-4",
            title: "Jai'Len Josey",
            artist: "Live at Apple Music Radio",
            subtitle: "Live at Apple Music Radio [E]",
            gradient: LinearGradient(colors: [Color(red: 0.65, green: 0.2, blue: 0.2), Color.black], startPoint: .top, endPoint: .bottom)
        ),
        SessionItem(
            id: "s-5",
            title: "Daniel Caesar",
            artist: "Live at Apple Music Sessions",
            subtitle: "Daniel Caesar Sessions",
            gradient: LinearGradient(colors: [Color(red: 0.15, green: 0.45, blue: 0.4), Color.black], startPoint: .top, endPoint: .bottom)
        )
    ]

    private var appleMusicSessionsSection: some View {
        ContinuousShelfView(
            title: "Apple Music Sessions",
            hasChevronHeader: true,
            items: sessionItems,
            spacing: 16,
            leadingInset: 28,
            pageSize: 4
        ) { item in
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(item.gradient)
                        .frame(width: 180, height: 180)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                        )

                    VStack(alignment: .leading) {
                        HStack {
                            Spacer()
                            HStack(spacing: 2) {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Music")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(10)
                        }

                        Spacer()

                        Text(item.title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 12)

                        Text(item.artist)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 12)
                    }
                }

                Text(item.subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: 180, alignment: .leading)
            }
        }
    }

    // MARK: - 3. Club DJ 混音精选 (Club DJ Mixes Shelf)

    private struct DJMixItem: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let gradient: LinearGradient
    }

    private let djMixes: [DJMixItem] = [
        DJMixItem(
            id: "dj-1",
            title: "Max Styler",
            subtitle: "Club Mix 008: Max Styler (DJ Mix)",
            gradient: LinearGradient(colors: [Color.green.opacity(0.7), Color.black], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        DJMixItem(
            id: "dj-2",
            title: "Yung Singh",
            subtitle: "Beats In Space 218: Yung Singh",
            gradient: LinearGradient(colors: [Color.orange.opacity(0.7), Color.black], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        DJMixItem(
            id: "dj-3",
            title: "Jacques Greene",
            subtitle: "NAINA Presents: Jacques Greene (DJ Mix)",
            gradient: LinearGradient(colors: [Color.purple.opacity(0.7), Color.black], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        DJMixItem(
            id: "dj-4",
            title: "NAINA b2b",
            subtitle: "NAINA Presents: NAINA b2b (DJ Mix)",
            gradient: LinearGradient(colors: [Color.blue.opacity(0.7), Color.black], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        DJMixItem(
            id: "dj-5",
            title: "Z世代 混音榜",
            subtitle: "Club DJ Showcase: Volume 70",
            gradient: LinearGradient(colors: [Color.cyan.opacity(0.7), Color.black], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    ]

    private var clubDJMixesSection: some View {
        ContinuousShelfView(
            title: "Club DJ 混音精选",
            hasChevronHeader: true,
            items: djMixes,
            spacing: 16,
            leadingInset: 28,
            pageSize: 4
        ) { item in
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(item.gradient)
                        .frame(width: 180, height: 180)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                        )

                    VStack(alignment: .leading) {
                        HStack {
                            Spacer()
                            HStack(spacing: 2) {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Music")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(10)
                        }

                        Spacer()

                        Text(item.title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .padding(12)
                    }
                }

                Text(item.subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: 180, alignment: .leading)
            }
        }
    }

    // MARK: - 4. 最新发布与热门 (New Releases 3-Row Grid)

    private struct SampleTrackItem: Identifiable {
        let id: String
        let title: String
        let artist: String
        let isExplicit: Bool
        let color: Color
    }

    private let sampleTracks: [SampleTrackItem] = [
        SampleTrackItem(id: "t1", title: "Cruel Summer", artist: "Taylor Swift", isExplicit: false, color: .pink),
        SampleTrackItem(id: "t2", title: "Paint The Town Red", artist: "Doja Cat", isExplicit: true, color: .red),
        SampleTrackItem(id: "t3", title: "Snooze", artist: "SZA", isExplicit: false, color: .orange),
        SampleTrackItem(id: "t4", title: "Vampire", artist: "Olivia Rodrigo", isExplicit: true, color: .purple),
        SampleTrackItem(id: "t5", title: "Fast Car", artist: "Luke Combs", isExplicit: false, color: .blue),
        SampleTrackItem(id: "t6", title: "Last Night", artist: "Morgan Wallen", isExplicit: false, color: .green),
        SampleTrackItem(id: "t7", title: "Kill Bill", artist: "SZA", isExplicit: true, color: .indigo),
        SampleTrackItem(id: "t8", title: "Greedy", artist: "Tate McRae", isExplicit: false, color: .teal),
        SampleTrackItem(id: "t9", title: "Flowers", artist: "Miley Cyrus", isExplicit: false, color: .yellow)
    ]

    private var newReleasesSection: some View {
        ContinuousShelfContainer(
            title: "热门单曲与最新发行",
            subtitle: "今日热度精选",
            hasChevronHeader: true,
            leadingInset: 28
        ) {
            LazyHGrid(
                rows: [
                    GridItem(.fixed(56), spacing: 10),
                    GridItem(.fixed(56), spacing: 10),
                    GridItem(.fixed(56), spacing: 10)
                ],
                spacing: 24
            ) {
                ForEach(sampleTracks) { track in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(track.color.gradient)
                            .frame(width: 48, height: 48)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white.opacity(0.8))
                            )

                        VStack(alignment: .leading, spacing: 3) {
                            Text(track.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            HStack(spacing: 4) {
                                if track.isExplicit {
                                    Text("E")
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 3)
                                        .padding(.vertical, 1)
                                        .background(Color.secondary.opacity(0.2))
                                        .clipShape(RoundedRectangle(cornerRadius: 2))
                                }

                                Text(track.artist)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        Button {
                            // Quick trigger search for this track
                            feature.send(.queryChanged(track.title))
                            feature.send(.searchRequested(track.title))
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(width: 280)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        feature.send(.queryChanged(track.title))
                        feature.send(.searchRequested(track.title))
                    }
                }
            }
        }
    }

    // MARK: - 5. 探索流派与分类 (Explore by Genre Colorful Tiles)

    private struct GenreTileItem: Identifiable {
        let id: String
        let name: String
        let query: String
        let gradient: LinearGradient
    }

    private let genreTiles: [GenreTileItem] = [
        GenreTileItem(
            id: "pop",
            name: "流行",
            query: "Pop",
            gradient: LinearGradient(colors: [Color(red: 0.95, green: 0.35, blue: 0.55), Color(red: 0.7, green: 0.15, blue: 0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        GenreTileItem(
            id: "rock",
            name: "摇滚",
            query: "Rock",
            gradient: LinearGradient(colors: [Color(red: 0.85, green: 0.25, blue: 0.15), Color(red: 0.45, green: 0.1, blue: 0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        GenreTileItem(
            id: "jazz",
            name: "爵士",
            query: "Jazz",
            gradient: LinearGradient(colors: [Color(red: 0.45, green: 0.25, blue: 0.65), Color(red: 0.85, green: 0.65, blue: 0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        GenreTileItem(
            id: "classical",
            name: "古典",
            query: "Classical",
            gradient: LinearGradient(colors: [Color(red: 0.15, green: 0.35, blue: 0.65), Color(red: 0.05, green: 0.15, blue: 0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        GenreTileItem(
            id: "electronic",
            name: "电子",
            query: "Electronic",
            gradient: LinearGradient(colors: [Color(red: 0.15, green: 0.75, blue: 0.65), Color(red: 0.05, green: 0.35, blue: 0.45)], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        GenreTileItem(
            id: "soundtrack",
            name: "影视原声",
            query: "Soundtrack",
            gradient: LinearGradient(colors: [Color(red: 0.85, green: 0.55, blue: 0.2), Color(red: 0.5, green: 0.25, blue: 0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        GenreTileItem(
            id: "folk",
            name: "民谣",
            query: "Folk",
            gradient: LinearGradient(colors: [Color(red: 0.35, green: 0.65, blue: 0.35), Color(red: 0.15, green: 0.35, blue: 0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        GenreTileItem(
            id: "ambient",
            name: "氛围音乐",
            query: "Ambient",
            gradient: LinearGradient(colors: [Color(red: 0.4, green: 0.3, blue: 0.65), Color(red: 0.15, green: 0.4, blue: 0.65)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    ]

    private var exploreGenreTilesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("探索流派与分类")
                .font(.title2.bold())

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 240), spacing: 14)], spacing: 14) {
                ForEach(genreTiles) { tile in
                    Button {
                        feature.send(.queryChanged(tile.query))
                        feature.send(.searchRequested(tile.query))
                    } label: {
                        ZStack(alignment: .bottomLeading) {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(tile.gradient)
                                .frame(height: 80)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                                )
                                .shadow(color: .black.opacity(0.18), radius: 6, y: 3)

                            Text(tile.name)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(14)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 6. Openverse 搜索结果

    @ViewBuilder
    private var openverseResultsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Openverse 音频精选")
                    .font(.title2.bold())

                Spacer()

                if !state.results.isEmpty {
                    Text("\(state.results.count) 首音频")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if state.isLoading && state.results.isEmpty {
                loadingState
            } else if let error = state.errorMessage, state.results.isEmpty {
                errorState(error)
            } else if state.results.isEmpty {
                ContentUnavailableView(
                    "暂无音频",
                    systemImage: "music.note",
                    description: Text("请尝试点击上方流派磁贴或搜索其他关键词。")
                )
                .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 18) {
                    ForEach(state.results) { item in
                        audioCard(item)
                    }
                }
            }
        }
    }

    // MARK: - Loading & Error

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("正在连接 Openverse 检索全球音频…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private func errorState(_ error: String) -> some View {
        ContentUnavailableView {
            Label("暂时无法连接 Openverse", systemImage: "wifi.exclamationmark")
        } description: {
            Text(error)
        } actions: {
            Button("重试") {
                feature.send(.retryRequested)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - Audio Card

    private func audioCard(_ item: OpenverseAudio) -> some View {
        let isCurrent = feature.isCurrent(item)
        let isSaved = feature.isSaved(item)

        return VStack(alignment: .leading, spacing: 12) {
            artwork(item)

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(item.creatorTitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(item.summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            metadata(item)

            HStack(spacing: 8) {
                Button {
                    feature.send(.playPauseRequested(item))
                } label: {
                    Label(
                        isCurrent && feature.isPlaying ? "暂停" : "播放",
                        systemImage: isCurrent && feature.isPlaying ? "pause.fill" : "play.fill"
                    )
                }
                .buttonStyle(.bordered)

                Spacer()

                if isSaved {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                        .help("已在资料库中")
                } else {
                    Button {
                        Task {
                            feature.send(.libraryToggleRequested(item))
                        }
                    } label: {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("添加到资料库")
                }

                Menu {
                    actions(for: item)
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 24, height: 22)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
        .padding(14)
        .background(
            .quaternary,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isCurrent ? Color.primary.opacity(0.24) : Color.clear, lineWidth: 1)
        }
        .contextMenu {
            actions(for: item)
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private func actions(for item: OpenverseAudio) -> some View {
        Button {
            feature.send(.playNextRequested(item))
        } label: {
            Label("插播到下一首", systemImage: "text.line.first.and.arrowtriangle.forward")
        }

        Button {
            feature.send(.addToQueueRequested(item))
        } label: {
            Label("添加到播放队列", systemImage: "text.badge.plus")
        }

        Divider()

        if feature.isSaved(item) {
            Button {
                feature.send(.libraryToggleRequested(item))
            } label: {
                Label("从资料库中移除", systemImage: "minus.circle")
            }
        } else {
            Button {
                feature.send(.libraryToggleRequested(item))
            } label: {
                Label("添加到资料库", systemImage: "plus.circle")
            }
        }
    }

    // MARK: - Metadata

    private func metadata(_ item: OpenverseAudio) -> some View {
        HStack(spacing: 6) {
            Text(item.sourceTitle)
                .lineLimit(1)

            Text("·")

            Text(item.licenseTitle)
                .lineLimit(1)

            if let duration = item.durationText {
                Text("·")
                Text(duration)
                    .monospacedDigit()
            }
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }

    // MARK: - Artwork

    @ViewBuilder
    private func artwork(_ item: OpenverseAudio) -> some View {
        MediaImageView(
            url: item.thumbnailURL,
            thumbnailPixelSize: CGSize(width: 256, height: 256),
            cornerRadius: 12
        )
    }
}

// MARK: - Preview

#Preview("Browse") {
    @Previewable @State var showsContext = false
    let scene = MSRUPreviewData.makeScene(section: .browse)
    let session = MSRUApplicationShellSession(scene: scene)
    SwiftUIApplicationShell(shell: session.resolve(), isContextPresented: $showsContext) {
        SidebarPaneView(scene: scene)
    }
    .frame(width: 1100, height: 800)
}

#Preview("Browse · Content") {
    BrowseView(feature: MSRUPreviewData.makeBrowseFeature()).frame(width: 900, height: 700)
}

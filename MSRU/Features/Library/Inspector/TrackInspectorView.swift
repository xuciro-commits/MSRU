//
//  TrackInspectorView.swift
//  MSRU
//

import SwiftUI
import Observation
import AppFoundationUI

struct TrackInspectorView: View {

    var libraryTrack: LibraryTrack? = nil
    var localTrack: LocalTrack? = nil
    var musicContent: MusicContent? = nil

    @Bindable var playback: PlaybackController
    @Bindable var library: LibraryStore

    var onRevealInFinder: ((URL) -> Void)? = nil
    var onClose: (() -> Void)? = nil

    @State private var inspectorTab: InspectorTab = .details
    @State private var titleOverlayTier: String = "权威 Canonical"
    @State private var artistOverlayTier: String = "多语言 Alias"
    @State private var albumOverlayTier: String = "权威 Canonical"
    @State private var tagOverlayTier: String = "原始 Original"

    enum InspectorTab: String, CaseIterable, Identifiable {
        case details = "曲目详情"
        case versions = "版本列表 (3)"
        case overlay = "元数据覆盖层"
        var id: String { rawValue }
    }

    var body: some View {
        Group {
            if let track = libraryTrack {
                libraryTrackContent(track)
            } else if let track = localTrack {
                localTrackContent(track)
            } else if let content = musicContent {
                musicContentDetails(content)
            } else {
                emptySelectionView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tint(Color.accentColor)
    }

    // MARK: - Library Track Content

    private var tabPicker: some View {
        HStack(spacing: 3) {
            ForEach(InspectorTab.allCases) { tab in
                let isSelected = inspectorTab == tab
                Button {
                    inspectorTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                        .lineLimit(1)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 4)
                        .frame(maxWidth: .infinity)
                        .background(
                            isSelected ? Color.accentColor : Color.primary.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                        )
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private func libraryTrackContent(_ track: LibraryTrack) -> some View {
        VStack(spacing: 0) {
            tabPicker

            switch inspectorTab {
            case .details:
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header & Artwork
                        VStack(alignment: .center, spacing: 14) {
                            artwork(track)
                                .frame(width: 160, height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)

                            VStack(spacing: 4) {
                                Text(track.title)
                                    .font(.title3.bold())
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)

                                Text(track.artist + (track.album.map { " · " + $0 } ?? ""))
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)

                        // Action Buttons
                        actionsSection(track)

                        Divider()

                        // Properties
                        propertiesSection(track)

                        Divider()

                        // Source (Read-only)
                        sourceSection(track)
                    }
                    .padding(18)
                }
                .scrollIndicators(.hidden)
                .hideScrollIndicatorsCompletely()
            case .versions:
                ScrollView {
                    versionsContent(title: track.title)
                }
                .scrollIndicators(.hidden)
                .hideScrollIndicatorsCompletely()
            case .overlay:
                ScrollView {
                    overlayContent(title: track.title, artist: track.artist, album: track.album)
                }
                .scrollIndicators(.hidden)
                .hideScrollIndicatorsCompletely()
            }
        }
    }

    private func actionsSection(_ track: LibraryTrack) -> some View {
        VStack(spacing: 10) {
            let item = PlaybackItem(library: track)
            let isCurrent = playback.currentItem?.id == item?.id
            let isPlaying = isCurrent && playback.isPlaying

            HStack(spacing: 10) {
                Button {
                    playback.toggle(library: track)
                } label: {
                        Label(isPlaying ? "暂停" : "播放", systemImage: isPlaying ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accentColor)
                .disabled(item == nil)

                let isSaved = library.contains(id: track.id)
                Button {
                    Task {
                        if isSaved {
                            await library.remove(id: track.id)
                        } else {
                            await library.add(track)
                        }
                    }
                } label: {
                    Image(systemName: isSaved ? "heart.fill" : "heart")
                        .foregroundStyle(isSaved ? Color.red : Color.primary)
                }
                .buttonStyle(.bordered)
                .tint(Color.accentColor)
                .help(isSaved ? "从资料库移除" : "加入资料库")
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    Button {
                        playback.playNext(track)
                    } label: {
                        Label("下一首播放", systemImage: "text.line.first.and.arrowtriangle.forward")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.accentColor)
                    .disabled(item == nil)

                    Button {
                        playback.addToQueue(track)
                    } label: {
                        Label("加入队列", systemImage: "text.badge.plus")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.accentColor)
                    .disabled(item == nil)
                }

                VStack(spacing: 8) {
                    Button {
                        playback.playNext(track)
                    } label: {
                        Label("下一首播放", systemImage: "text.line.first.and.arrowtriangle.forward")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.accentColor)
                    .disabled(item == nil)

                    Button {
                        playback.addToQueue(track)
                    } label: {
                        Label("加入队列", systemImage: "text.badge.plus")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.accentColor)
                    .disabled(item == nil)
                }
            }
        }
    }

    private func propertiesSection(_ track: LibraryTrack) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("属性")
                .font(.headline)
                .foregroundStyle(.secondary)

            propertyRow(label: "标题", value: track.title)
            propertyRow(label: "艺术家", value: track.artist)
            if let album = track.album {
                propertyRow(label: "专辑", value: album)
            }
            if let duration = track.duration {
                propertyRow(label: "时长", value: durationString(duration))
            }
            propertyRow(label: "添加时间", value: track.dateAdded.formatted(date: .abbreviated, time: .shortened))
            let sourceSummary = track.sources.map { $0.kind.rawValue.capitalized }.joined(separator: ", ")
            if !sourceSummary.isEmpty {
                propertyRow(label: "来源", value: sourceSummary)
            }
        }
    }

    private func sourceSection(_ track: LibraryTrack) -> some View {
        let localSource = track.sources.first { $0.kind == .local && $0.localFileURL != nil }
        return VStack(alignment: .leading, spacing: 10) {
            Text("来源（只读）")
                .font(.headline)
                .foregroundStyle(.secondary)

            if let localSource, let fileURL = localSource.localFileURL {
                propertyRow(label: "Kind", value: "Local Audio File")
                propertyRow(label: "Format", value: fileURL.pathExtension.uppercased())
                if let size = fileSizeString(for: fileURL) {
                    propertyRow(label: "Size", value: size)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("位置")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(fileURL.path)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }

                if let onRevealInFinder {
                    Button {
                        onRevealInFinder(fileURL)
                    } label: {
                        Label("在访达中显示", systemImage: "arrow.up.forward.square")
                            .font(.callout)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 4)
                }
            } else {
                let kindName = track.sources.first?.kind.rawValue.capitalized ?? "Remote Catalog"
                propertyRow(label: "Kind", value: kindName)
                if let externalID = track.sources.first?.externalID {
                    propertyRow(label: "External ID", value: externalID)
                }
            }
        }
    }

    // MARK: - Local Track Content

    private func localTrackContent(_ track: LocalTrack) -> some View {
        VStack(spacing: 0) {
            tabPicker

            switch inspectorTab {
            case .details:
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header & Artwork
                        VStack(alignment: .center, spacing: 14) {
                            artwork(track)
                                .frame(width: 160, height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)

                            VStack(spacing: 4) {
                                Text(track.title)
                                    .font(.title3.bold())
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)

                                Text(track.artist + (track.album.map { " · " + $0 } ?? ""))
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)

                        // Action Buttons
                        actionsSection(track)

                        Divider()

                        // Properties
                        propertiesSection(track)

                        Divider()

                        // Source (Read-only)
                        sourceSection(track)
                    }
                    .padding(18)
                }
                .scrollIndicators(.hidden)
                .hideScrollIndicatorsCompletely()
            case .versions:
                ScrollView {
                    versionsContent(title: track.title)
                }
                .scrollIndicators(.hidden)
                .hideScrollIndicatorsCompletely()
            case .overlay:
                ScrollView {
                    overlayContent(title: track.title, artist: track.artist, album: track.album)
                }
                .scrollIndicators(.hidden)
                .hideScrollIndicatorsCompletely()
            }
        }
    }

    // MARK: - Versions & Overlay Panels (InteractionAtlas 9.2)

    private func versionsContent(title: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("当前首选版本 (Primary Version):")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Color.yellow)
                    Text("2020 Remaster · FLAC 24-bit/96kHz (母带)")
                        .font(.callout.bold())
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.yellow.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("所有可用版本 (Versions):")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                versionItemRow(isPrimary: true, tag: "[★ 首选]", desc: "2020 Remaster (FLAC 24/96)", size: "104.2 MB")
                versionItemRow(isPrimary: false, tag: "[备选]", desc: "2003 Taiwan CD (FLAC 16/44.1)", size: "28.6 MB")
                versionItemRow(isPrimary: false, tag: "[便携]", desc: "Digital Release (AAC 256k)", size: "8.4 MB")
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("操作：")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        Button("设为首选版本") {}
                            .buttonStyle(.borderedProminent)
                            .tint(Color.accentColor)
                            .controlSize(.small)

                        Button("在访达中显示") {}
                            .buttonStyle(.bordered)
                            .tint(Color.accentColor)
                            .controlSize(.small)

                        Button("移出本组版本") {}
                            .buttonStyle(.bordered)
                            .tint(Color.accentColor)
                            .controlSize(.small)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Button("设为首选版本") {}
                            .buttonStyle(.borderedProminent)
                            .tint(Color.accentColor)
                            .controlSize(.small)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button("在访达中显示") {}
                            .buttonStyle(.bordered)
                            .tint(Color.accentColor)
                            .controlSize(.small)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button("移出本组版本") {}
                            .buttonStyle(.bordered)
                            .tint(Color.accentColor)
                            .controlSize(.small)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(18)
    }

    private func versionItemRow(isPrimary: Bool, tag: String, desc: String, size: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isPrimary ? "record.circle.fill" : "circle")
                .foregroundStyle(isPrimary ? Color.accentColor : Color.secondary)

            Text(tag)
                .font(.caption.bold())
                .foregroundStyle(isPrimary ? Color.accentColor : Color.secondary)

            Text(desc)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(size)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
        .padding(8)
        .background(isPrimary ? Color.accentColor.opacity(0.18) : Color.clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(isPrimary ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }

    private func overlayContent(title: String, artist: String, album: String?) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("三层元数据覆盖设置：")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            overlaySelectorRow(field: "• 标题：", selection: $titleOverlayTier, value: "(\(title))", options: ["权威 Canonical", "用户 User", "原始 Original"])
            overlaySelectorRow(field: "• 歌手：", selection: $artistOverlayTier, value: "(\(artist))", options: ["权威 Canonical", "多语言 Alias", "原始 Original"])
            overlaySelectorRow(field: "• 专辑：", selection: $albumOverlayTier, value: "(\(album ?? "未设置"))", options: ["权威 Canonical", "用户 User", "原始 Original"])
            overlaySelectorRow(field: "• 标签：", selection: $tagOverlayTier, value: "(绝不篡改原文件)", options: ["原始 Original", "锁定不可写"])

            Divider()

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    Button("重置所有覆盖为权威") {
                        titleOverlayTier = "权威 Canonical"
                        artistOverlayTier = "权威 Canonical"
                        albumOverlayTier = "权威 Canonical"
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.accentColor)
                    .controlSize(.small)

                    Spacer()

                    Button("回退至文件原始标签") {
                        titleOverlayTier = "原始 Original"
                        artistOverlayTier = "原始 Original"
                        albumOverlayTier = "原始 Original"
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.accentColor)
                    .controlSize(.small)
                }

                VStack(spacing: 8) {
                    Button("重置所有覆盖为权威") {
                        titleOverlayTier = "权威 Canonical"
                        artistOverlayTier = "权威 Canonical"
                        albumOverlayTier = "权威 Canonical"
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.accentColor)
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)

                    Button("回退至文件原始标签") {
                        titleOverlayTier = "原始 Original"
                        artistOverlayTier = "原始 Original"
                        albumOverlayTier = "原始 Original"
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.accentColor)
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(18)
    }

    private func overlaySelectorRow(field: String, selection: Binding<String>, value: String, options: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    Text(field)
                        .font(.caption.bold())
                        .frame(width: 55, alignment: .leading)
                        .lineLimit(1)

                    Picker("", selection: selection) {
                        ForEach(options, id: \.self) { opt in
                            Text(opt).tag(opt)
                        }
                    }
                    .labelsHidden()
                    .tint(Color.accentColor)
                    .frame(maxWidth: 140)

                    Spacer()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(field)
                        .font(.caption.bold())

                    Picker("", selection: selection) {
                        ForEach(options, id: \.self) { opt in
                            Text(opt).tag(opt)
                        }
                    }
                    .labelsHidden()
                    .tint(Color.accentColor)
                }
            }

            Text(value)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.leading, 8)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    // MARK: - Actions Section

    private func actionsSection(_ track: LocalTrack) -> some View {
        VStack(spacing: 10) {
            let isCurrent = playback.currentTrack?.id == track.id
            let isPlaying = isCurrent && playback.isPlaying

            HStack(spacing: 10) {
                Button {
                    playback.toggle(track: track, queue: [track])
                } label: {
                    Label(isPlaying ? "暂停" : "播放", systemImage: isPlaying ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accentColor)

                let isSaved = library.contains(local: track)
                Button {
                    Task {
                        if isSaved {
                            await library.remove(local: track)
                        } else {
                            await library.add(local: track)
                        }
                    }
                } label: {
                    Image(systemName: isSaved ? "heart.fill" : "heart")
                        .foregroundStyle(isSaved ? Color.red : Color.primary)
                }
                .buttonStyle(.bordered)
                .tint(Color.accentColor)
                .help(isSaved ? "从资料库移除" : "加入资料库")
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    Button {
                        playback.playNext(track)
                    } label: {
                        Label("下一首播放", systemImage: "text.line.first.and.arrowtriangle.forward")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.accentColor)

                    Button {
                        playback.addToQueue(track)
                    } label: {
                        Label("加入队列", systemImage: "text.badge.plus")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.accentColor)
                }

                VStack(spacing: 8) {
                    Button {
                        playback.playNext(track)
                    } label: {
                        Label("下一首播放", systemImage: "text.line.first.and.arrowtriangle.forward")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.accentColor)

                    Button {
                        playback.addToQueue(track)
                    } label: {
                        Label("加入队列", systemImage: "text.badge.plus")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.accentColor)
                }
            }
        }
    }

    // MARK: - Properties Section

    private func propertiesSection(_ track: LocalTrack) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("属性")
                .font(.headline)
                .foregroundStyle(.secondary)

            propertyRow(label: "标题", value: track.title)
            propertyRow(label: "艺术家", value: track.artist)
            if let album = track.album {
                propertyRow(label: "专辑", value: album)
            }
            propertyRow(label: "时长", value: durationString(track.duration))
            propertyRow(label: "格式", value: track.fileURL.pathExtension.uppercased())
            if let fileSize = fileSizeString(for: track.fileURL) {
                propertyRow(label: "大小", value: fileSize)
            }
        }
    }

    // MARK: - Source Section

    private func sourceSection(_ track: LocalTrack) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("来源（只读）")
                .font(.headline)
                .foregroundStyle(.secondary)

            propertyRow(label: "类型", value: "本地音频文件")

            VStack(alignment: .leading, spacing: 4) {
                Text("位置")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(track.fileURL.path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .textSelection(.enabled)
            }

            if let onRevealInFinder {
                Button {
                    onRevealInFinder(track.fileURL)
                } label: {
                    Label("在访达中显示", systemImage: "arrow.up.forward.square")
                        .font(.callout)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Music Content (Remote / Catalog)

    private func musicContentDetails(_ content: MusicContent) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .center, spacing: 14) {
                    AsyncImage(url: content.artworkURL) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFill()
                        } else {
                            placeholderArtwork
                        }
                    }
                    .frame(width: 160, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)

                    VStack(spacing: 4) {
                        Text(content.title)
                            .font(.title3.bold())
                            .multilineTextAlignment(.center)
                            .lineLimit(2)

                        if let subtitle = content.subtitle {
                            Text(subtitle)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 12)

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("详情")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    propertyRow(label: "标题", value: content.title)
                    if let subtitle = content.subtitle {
                        propertyRow(label: "副标题", value: subtitle)
                    }
                    propertyRow(label: "服务提供方", value: content.provider.title)
                    propertyRow(label: "类型", value: content.kind.rawValue.capitalized)
                }
            }
            .padding(18)
        }
        .scrollIndicators(.hidden)
        .hideScrollIndicatorsCompletely()
    }

    // MARK: - Empty State

    private var emptySelectionView: some View {
        ContentUnavailableView {
            Label("未选择曲目", systemImage: "music.note")
        } description: {
            Text("从资料库或浏览页面选择一首曲目，以查看属性和音频详情。")
        }
    }

    // MARK: - Row Helper

    private func propertyRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)

            Text(value)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private func artwork(_ track: LibraryTrack) -> some View {
        if let data = track.artworkData, let image = Image(artworkData: data) {
            image
                .resizable()
                .scaledToFill()
        } else if let url = track.artworkURL {
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    placeholderArtwork
                }
            }
        } else {
            placeholderArtwork
        }
    }

    @ViewBuilder
    private func artwork(_ track: LocalTrack) -> some View {
        if let data = track.artworkData, let image = Image(artworkData: data) {
            image
                .resizable()
                .scaledToFill()
        } else {
            placeholderArtwork
        }
    }

    private var placeholderArtwork: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.secondary.opacity(0.15))
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
            }
    }

    // MARK: - Formatters

    private func durationString(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    private func fileSizeString(for url: URL) -> String? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else {
            return nil
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

// MARK: - Preview

#Preview("Track Inspector · Populated") {
    let application = MSRUPreviewData.makeApplication()
    TrackInspectorView(
        localTrack: MSRUPreviewData.localTracks[0],
        musicContent: nil,
        playback: application.playback,
        library: application.library,
        onRevealInFinder: { _ in },
        onClose: {}
    )
    .frame(width: 320, height: 600)
}

#Preview("Track Inspector · Library Track") {
    let saved = LibraryTrack(local: MSRUPreviewData.localTracks[0])
    let application = MSRUPreviewData.makeApplication(savedTracks: [saved])
    TrackInspectorView(
        libraryTrack: saved,
        localTrack: nil,
        musicContent: nil,
        playback: application.playback,
        library: application.library,
        onRevealInFinder: { _ in },
        onClose: {}
    )
    .frame(width: 320, height: 600)
}

#Preview("Track Inspector · Empty") {
    let application = MSRUPreviewData.makeApplication()
    TrackInspectorView(
        localTrack: nil,
        musicContent: nil,
        playback: application.playback,
        library: application.library,
        onRevealInFinder: { _ in },
        onClose: {}
    )
    .frame(width: 320, height: 600)
}

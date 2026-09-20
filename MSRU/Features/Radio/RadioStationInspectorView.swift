//
//  RadioStationInspectorView.swift
//  MSRU
//

import SwiftUI
import Observation
import AppFoundationUI

struct RadioStationInspectorView: View {

    let station: RadioStation
    @Bindable var playback: PlaybackController
    var isFavorite: Bool = false
    var onToggleFavorite: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onClose: (() -> Void)? = nil

    private var isCurrent: Bool {
        playback.currentItem?.radioStation?.id == station.id
    }

    private var isPlaying: Bool {
        isCurrent && playback.isPlaying
    }

    private var isResolving: Bool {
        isCurrent && playback.isResolving
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header & Artwork
                VStack(alignment: .center, spacing: 14) {
                    artwork
                        .frame(width: 160, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)

                    VStack(spacing: 6) {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(isPlaying ? Color.red : Color.secondary)
                                .frame(width: 7, height: 7)
                            Text(isPlaying ? "直播广播" : "互联网电台")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(0.8)
                                .foregroundStyle(isPlaying ? Color.red : Color.secondary)
                        }

                        Text(station.name)
                            .font(.title3.bold())
                            .multilineTextAlignment(.center)
                            .lineLimit(2)

                            Text(station.genre.displayTitle + " · " + station.country)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 12)

                // Action Section
                actionsSection

                Divider()

                // Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("关于电台")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text(station.description)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                // Properties Section
                propertiesSection

                Divider()

                // Broadcast & Links Section
                broadcastSection
            }
            .padding(18)
        }
        .scrollIndicators(.hidden)
        .hideScrollIndicatorsCompletely()
        .tint(Color.accentColor)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    playback.toggle(radio: station)
                } label: {
                    HStack {
                        if isResolving {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.trailing, 4)
                        }
                        Label(
                            isPlaying ? "暂停流媒体" : "调入电台",
                            systemImage: isPlaying ? "pause.fill" : "play.fill"
                        )
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accentColor)

                if let onToggleFavorite {
                    Button(action: onToggleFavorite) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .foregroundStyle(isFavorite ? Color.red : Color.primary)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.accentColor)
                    .help(isFavorite ? "取消收藏" : "加入收藏")
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    Button {
                        playback.playNext(radio: station)
                    } label: {
                        Label("下一首播放", systemImage: "text.line.first.and.arrowtriangle.forward")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.accentColor)

                    Button {
                        playback.addToQueue(radio: station)
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
                        playback.playNext(radio: station)
                    } label: {
                        Label("下一首播放", systemImage: "text.line.first.and.arrowtriangle.forward")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.accentColor)

                    Button {
                        playback.addToQueue(radio: station)
                    } label: {
                        Label("加入队列", systemImage: "text.badge.plus")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.accentColor)
                }
            }

            if station.isCustom, let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("删除自定义电台", systemImage: "trash")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Properties Section

    private var propertiesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("广播详情")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                propertyRow(title: "类型", value: station.genre.displayTitle)
                propertyRow(title: "国家/地区", value: station.country)
                propertyRow(title: "语言", value: station.language)
                propertyRow(title: "音频编码", value: station.codec)
                if let bitrate = station.bitrateKbps {
                    propertyRow(title: "流媒体码率", value: "\(bitrate) kbps")
                }
                if station.isCustom {
                    propertyRow(title: "来源", value: "自定义流媒体")
                }
            }
            .padding(12)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func propertyRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Broadcast URL & Homepage

    private var broadcastSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("流媒体与网页链接")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("流媒体 URL")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(station.streamURL.absoluteString)
                            .font(.caption2)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                }

                if let homepageURL = station.homepageURL {
                    Link(destination: homepageURL) {
                        HStack {
                            Label("官方网站", systemImage: "safari")
                                .font(.subheadline)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }
            }
            .padding(12)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Artwork

    private var artwork: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: station.genre.systemImage)
                .font(.system(size: 60, weight: .light))
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}

#Preview("Radio Station Inspector") {
    let playback = MSRUPreviewData.makePlaybackController()
    let station = RadioStation.defaultStations[0]
    return RadioStationInspectorView(
        station: station,
        playback: playback,
        isFavorite: true,
        onToggleFavorite: {},
        onClose: {}
    )
    .frame(width: 320, height: 600)
}

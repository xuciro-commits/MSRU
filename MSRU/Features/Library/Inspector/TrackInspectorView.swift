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
    @State private var titleOverlayTier: String = "Canonical"
    @State private var artistOverlayTier: String = "Multi-language Alias"
    @State private var albumOverlayTier: String = "Canonical"
    @State private var tagOverlayTier: String = "Original"

    enum InspectorTab: String, CaseIterable, Identifiable {
        case details = "Track Details"
        case versions = "Versions (3)"
        case overlay = "Metadata Override Layers"
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
                    Text(LocalizedStringKey(tab.rawValue))
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
                        Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill")
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
                .help(isSaved ? "Remove from Library" : "Add to Library")
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    Button {
                        playback.playNext(track)
                    } label: {
                        Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.accentColor)
                    .disabled(item == nil)

                    Button {
                        playback.addToQueue(track)
                    } label: {
                        Label("Add to Queue", systemImage: "text.badge.plus")
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
                        Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.accentColor)
                    .disabled(item == nil)

                    Button {
                        playback.addToQueue(track)
                    } label: {
                        Label("Add to Queue", systemImage: "text.badge.plus")
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
            Text("Properties")
                .font(.headline)
                .foregroundStyle(.secondary)

            propertyRow(label: "Title", value: track.title)
            propertyRow(label: "Artist", value: track.artist)
            if let album = track.album {
                propertyRow(label: "Album", value: album)
            }
            if let duration = track.duration {
                propertyRow(label: "Duration", value: durationString(duration))
            }
            propertyRow(label: "Date Added", value: track.dateAdded.formatted(date: .abbreviated, time: .shortened))
            let sourceSummary = track.sources.map { $0.kind.rawValue.capitalized }.joined(separator: ", ")
            if !sourceSummary.isEmpty {
                propertyRow(label: "Source", value: sourceSummary)
            }
        }
    }

    private func sourceSection(_ track: LibraryTrack) -> some View {
        let localSource = track.sources.first { $0.kind == .local && $0.localFileURL != nil }
        return VStack(alignment: .leading, spacing: 10) {
            Text("Source (Read-only)")
                .font(.headline)
                .foregroundStyle(.secondary)

            if let localSource, let fileURL = localSource.localFileURL {
                propertyRow(label: "Kind", value: "Local Audio File")
                propertyRow(label: "Format", value: fileURL.pathExtension.uppercased())
                if let size = fileSizeString(for: fileURL) {
                    propertyRow(label: "Size", value: size)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Location")
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
                        Label("Reveal in Finder", systemImage: "arrow.up.forward.square")
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
                Text("Current Primary Version:")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Color.yellow)
                    Text("2020 Remaster · FLAC 24-bit/96kHz (Master)")
                        .font(.callout.bold())
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.yellow.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("All Available Versions:")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                versionItemRow(isPrimary: true, tag: "[★ Primary]", desc: "2020 Remaster (FLAC 24/96)", size: "104.2 MB")
                versionItemRow(isPrimary: false, tag: "[Alternate]", desc: "2003 Taiwan CD (FLAC 16/44.1)", size: "28.6 MB")
                versionItemRow(isPrimary: false, tag: "[Portable]", desc: "Digital Release (AAC 256k)", size: "8.4 MB")
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Actions:")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        Button("Set as Primary") {}
                            .buttonStyle(.borderedProminent)
                            .tint(Color.accentColor)
                            .controlSize(.small)

                        Button("Reveal in Finder") {}
                            .buttonStyle(.bordered)
                            .tint(Color.accentColor)
                            .controlSize(.small)

                        Button("Remove from Group") {}
                            .buttonStyle(.bordered)
                            .tint(Color.accentColor)
                            .controlSize(.small)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Button("Set as Primary") {}
                            .buttonStyle(.borderedProminent)
                            .tint(Color.accentColor)
                            .controlSize(.small)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button("Reveal in Finder") {}
                            .buttonStyle(.bordered)
                            .tint(Color.accentColor)
                            .controlSize(.small)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button("Remove from Group") {}
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
            Text("Three-layer Metadata Override Settings:")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            overlaySelectorRow(field: "• Title：", selection: $titleOverlayTier, value: "(\(title))", options: ["Canonical", "User", "Original"])
            overlaySelectorRow(field: "• Artist: ", selection: $artistOverlayTier, value: "(\(artist))", options: ["Canonical", "Multi-language Alias", "Original"])
            overlaySelectorRow(field: "• Album：", selection: $albumOverlayTier, value: "(\(album ?? "Not Set"))", options: ["Canonical", "User", "Original"])
            overlaySelectorRow(field: "• Tags: ", selection: $tagOverlayTier, value: "(Never modifies original files)", options: ["Original", "Locked / Read-only"])

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Fingerprint & External Catalog:")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Image(systemName: "waveform.badge.magnifyingglass")
                        .foregroundStyle(Color.accentColor)
                    Text("Local Acoustic Fingerprint Memory")
                        .font(.callout.bold())
                    Spacer()
                    Text("Active")
                        .font(.caption2.bold())
                        .foregroundStyle(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.12), in: Capsule())
                }
                .padding(10)
                .background(Color.secondary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Button {
                    Task {
                        _ = try? await MusicBrainzCatalogClient.shared.searchReleases(artist: artist, album: album ?? "")
                    }
                } label: {
                    Label("Online Re-identification (MusicBrainz)", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(Color.accentColor)
                .controlSize(.small)
            }

            Divider()

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    Button("Reset All Overrides to Canonical") {
                        titleOverlayTier = "Canonical"
                        artistOverlayTier = "Canonical"
                        albumOverlayTier = "Canonical"
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.accentColor)
                    .controlSize(.small)

                    Spacer()

                    Button("Revert to Original File Tags") {
                        titleOverlayTier = "Original"
                        artistOverlayTier = "Original"
                        albumOverlayTier = "Original"
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.accentColor)
                    .controlSize(.small)
                }

                VStack(spacing: 8) {
                    Button("Reset All Overrides to Canonical") {
                        titleOverlayTier = "Canonical"
                        artistOverlayTier = "Canonical"
                        albumOverlayTier = "Canonical"
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.accentColor)
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)

                    Button("Revert to Original File Tags") {
                        titleOverlayTier = "Original"
                        artistOverlayTier = "Original"
                        albumOverlayTier = "Original"
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
                    Text(LocalizedStringKey(field))
                        .font(.caption.bold())
                        .frame(width: 55, alignment: .leading)
                        .lineLimit(1)

                    Picker("", selection: selection) {
                        ForEach(options, id: \.self) { opt in
                            Text(LocalizedStringKey(opt)).tag(opt)
                        }
                    }
                    .labelsHidden()
                    .tint(Color.accentColor)
                    .frame(maxWidth: 140)

                    Spacer()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey(field))
                        .font(.caption.bold())

                    Picker("", selection: selection) {
                        ForEach(options, id: \.self) { opt in
                            Text(LocalizedStringKey(opt)).tag(opt)
                        }
                    }
                    .labelsHidden()
                    .tint(Color.accentColor)
                }
            }

            Text(LocalizedStringKey(value))
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
                    Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill")
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
                .help(isSaved ? "Remove from Library" : "Add to Library")
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    Button {
                        playback.playNext(track)
                    } label: {
                        Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.accentColor)

                    Button {
                        playback.addToQueue(track)
                    } label: {
                        Label("Add to Queue", systemImage: "text.badge.plus")
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
                        Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.accentColor)

                    Button {
                        playback.addToQueue(track)
                    } label: {
                        Label("Add to Queue", systemImage: "text.badge.plus")
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
            Text("Properties")
                .font(.headline)
                .foregroundStyle(.secondary)

            propertyRow(label: "Title", value: track.title)
            propertyRow(label: "Artist", value: track.artist)
            if let album = track.album {
                propertyRow(label: "Album", value: album)
            }
            propertyRow(label: "Duration", value: durationString(track.duration))
            propertyRow(label: "Format", value: track.fileURL.pathExtension.uppercased())
            if let fileSize = fileSizeString(for: track.fileURL) {
                propertyRow(label: "Size", value: fileSize)
            }
        }
    }

    // MARK: - Source Section

    private func sourceSection(_ track: LocalTrack) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Source (Read-only)")
                .font(.headline)
                .foregroundStyle(.secondary)

            propertyRow(label: "Genre", value: "Local Audio File")

            VStack(alignment: .leading, spacing: 4) {
                Text("Location")
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
                    Label("Reveal in Finder", systemImage: "arrow.up.forward.square")
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
                    Text("Details")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    propertyRow(label: "Title", value: content.title)
                    if let subtitle = content.subtitle {
                        propertyRow(label: "Subtitle", value: subtitle)
                    }
                    propertyRow(label: "Providers", value: content.provider.title)
                    propertyRow(label: "Genre", value: content.kind.rawValue.capitalized)
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
            Label("No Track Selected", systemImage: "music.note")
        } description: {
            Text("Select a track from Library or Browse to view properties and audio details.")
        }
    }

    // MARK: - Row Helper

    private func propertyRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(LocalizedStringKey(label))
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)

            Text(LocalizedStringKey(value))
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
        if let ref = track.artworkReference {
            ArtworkThumbnailView(
                reference: ref,
                targetSize: CGSize(width: 260, height: 260),
                placeholderSystemImage: "music.note",
                cornerRadius: 14
            )
        } else if let data = track.artworkData, let image = Image(artworkData: data) {
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

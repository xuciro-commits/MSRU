//
//  MetadataEditorSheet.swift
//  MSRU
//
//  Created for Professional Music Library Management.
//

import SwiftUI
import Observation
import UniformTypeIdentifiers
import AppFoundation
import AppFoundationUI
import MusicLibrary
import MusicPlayback

public struct MetadataEditorSheet: View {

    public let tracks: [LocalTrack]
    public let localStore: LocalLibraryStore
    public var onDismiss: () -> Void

    public init(
        tracks: [LocalTrack],
        localStore: LocalLibraryStore,
        onDismiss: @escaping () -> Void
    ) {
        self.tracks = tracks
        self.localStore = localStore
        self.onDismiss = onDismiss
    }

    @State private var selectedTab: EditorTab = .details
    @State private var isLoadingTags: Bool = true
    @State private var isSaving: Bool = false
    @State private var saveProgress: String = ""
    @State private var errorMessage: String? = nil
    @State private var showErrorAlert: Bool = false

    // Single-track metadata
    @State private var singleDetails: AudioFileDetails? = nil

    // Field states
    @State private var title: String = ""
    @State private var artist: String = ""
    @State private var albumArtist: String = ""
    @State private var album: String = ""
    @State private var genre: String = ""
    @State private var year: String = ""
    @State private var trackNumber: String = ""
    @State private var totalTracks: String = ""
    @State private var discNumber: String = ""
    @State private var totalDiscs: String = ""
    @State private var lyrics: String = ""

    // Artwork
    @State private var artworkData: Data? = nil
    @State private var artworkURL: URL? = nil
    @State private var isArtworkModified: Bool = false
    @State private var isFileImporterPresented: Bool = false

    // Batch mode flags
    @State private var applyArtist: Bool = false
    @State private var applyAlbumArtist: Bool = false
    @State private var applyAlbum: Bool = false
    @State private var applyGenre: Bool = false
    @State private var applyYear: Bool = false
    @State private var applyDiscNumber: Bool = false
    @State private var applyArtwork: Bool = false

    private var isBatch: Bool { tracks.count > 1 }

    enum EditorTab: String, CaseIterable, Identifiable {
        case details = "Details"
        case artwork = "Artwork"
        case lyrics = "Lyrics"
        case fileSpecs = "File & Specs"

        var id: String { rawValue }

        var localizedTitle: LocalizedStringKey {
            switch self {
            case .details: return "Details"
            case .artwork: return "Artwork"
            case .lyrics: return "Lyrics"
            case .fileSpecs: return "File & Specs"
            }
        }

        var systemImage: String {
            switch self {
            case .details: return "text.alignleft"
            case .artwork: return "photo"
            case .lyrics: return "quote.bubble"
            case .fileSpecs: return "info.circle"
            }
        }
    }

    private static let genrePresets = [
        "Classical", "Pop", "Rock", "Jazz", "Electronic",
        "R&B", "Soundtrack", "Acoustic", "Hi-Res", "Folk", "Instrumental"
    ]

    public var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()

            if isLoadingTags {
                loadingView
            } else {
                tabSelector
                Divider()

                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()
            bottomActionBar
        }
        .frame(minWidth: 580, idealWidth: 620, minHeight: 480, idealHeight: 540)
        .background(Color.platformWindowBackground)
        .task {
            await loadInitialMetadata()
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.image]
        ) { result in
            handlePickedImage(result: result)
        }
        .alert("Error Writing Metadata", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred while saving metadata.")
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 16) {
            Group {
                if let artworkData {
                    ArtworkThumbnailView(
                        reference: nil as String?,
                        fixedSize: CGSize(width: 56, height: 56)
                    )
                    .overlay {
                        #if canImport(AppKit)
                        if let nsImg = NSImage(data: artworkData) {
                            Image(nsImage: nsImg)
                                .resizable()
                                .scaledToFill()
                        }
                        #elseif canImport(UIKit)
                        if let uiImg = UIImage(data: artworkData) {
                            Image(uiImage: uiImg)
                                .resizable()
                                .scaledToFill()
                        }
                        #endif
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else if let first = tracks.first {
                    ArtworkThumbnailView(
                        reference: first.artworkReference,
                        fixedSize: CGSize(width: 56, height: 56)
                    )
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(width: 56, height: 56)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: 56, height: 56)
            .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 4) {
                if isBatch {
                    Text("\(tracks.count) Songs Selected")
                        .font(.title3.weight(.bold))
                    Text("Batch Metadata & Tag Editor")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let track = tracks.first {
                    Text(title.isEmpty ? track.title : title)
                        .font(.title3.weight(.bold))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(artist.isEmpty ? track.artist : artist)
                            .lineLimit(1)
                        if !album.isEmpty {
                            Text("—")
                            Text(album)
                                .lineLimit(1)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if let specs = singleDetails?.specs {
                        HStack(spacing: 6) {
                            Text(specs.formatName)
                            Text("•")
                            Text(specs.formattedSampleRate)
                            Text("•")
                            Text(specs.formattedBitDepth)
                        }
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.accentColor)
                    }
                }
            }

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 4) {
            ForEach(availableTabs) { tab in
                let isSelected = selectedTab == tab
                Button {
                    selectedTab = tab
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.systemImage)
                        Text(tab.localizedTitle)
                    }
                    .font(.callout.weight(isSelected ? .semibold : .regular))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        isSelected ? Color.accentColor.opacity(0.15) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                    .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    private var availableTabs: [EditorTab] {
        if isBatch {
            return [.details, .artwork]
        } else {
            return [.details, .artwork, .lyrics, .fileSpecs]
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .details:
            detailsTabView
        case .artwork:
            artworkTabView
        case .lyrics:
            lyricsTabView
        case .fileSpecs:
            fileSpecsTabView
        }
    }

    // MARK: - Details Tab View

    private var detailsTabView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if isBatch {
                    batchDetailsFields
                } else {
                    singleDetailsFields
                }
            }
            .padding(20)
        }
    }

    private var singleDetailsFields: some View {
        VStack(spacing: 12) {
            formRow(title: "Title") {
                TextField("Title", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            formRow(title: "Artist") {
                TextField("Artist", text: $artist)
                    .textFieldStyle(.roundedBorder)
            }

            formRow(title: "Album Artist") {
                TextField("Album Artist", text: $albumArtist)
                    .textFieldStyle(.roundedBorder)
            }

            formRow(title: "Album") {
                TextField("Album", text: $album)
                    .textFieldStyle(.roundedBorder)
            }

            formRow(title: "Genre") {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Genre", text: $genre)
                        .textFieldStyle(.roundedBorder)

                    // Quick genre presets
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Self.genrePresets, id: \.self) { preset in
                                Button(preset) {
                                    genre = preset
                                }
                                .buttonStyle(.plain)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.secondary.opacity(0.12), in: Capsule())
                            }
                        }
                    }
                }
            }

            formRow(title: "Year") {
                TextField("Year (e.g. 2024)", text: $year)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 160)
            }

            HStack(spacing: 20) {
                formRow(title: "Track") {
                    HStack(spacing: 6) {
                        TextField("#", text: $trackNumber)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                        Text("of")
                            .foregroundStyle(.secondary)
                        TextField("Total", text: $totalTracks)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                    }
                }

                formRow(title: "Disc") {
                    HStack(spacing: 6) {
                        TextField("#", text: $discNumber)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                        Text("of")
                            .foregroundStyle(.secondary)
                        TextField("Total", text: $totalDiscs)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                    }
                }
            }
        }
    }

    private var batchDetailsFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Select the fields you wish to batch update across all \(tracks.count) tracks:")
                .font(.callout)
                .foregroundStyle(.secondary)

            Divider()

            batchRow(label: "Artist", isEnabled: $applyArtist) {
                TextField("Set artist for all tracks", text: $artist)
                    .textFieldStyle(.roundedBorder)
                    .disabled(!applyArtist)
            }

            batchRow(label: "Album Artist", isEnabled: $applyAlbumArtist) {
                TextField("Set album artist for all tracks", text: $albumArtist)
                    .textFieldStyle(.roundedBorder)
                    .disabled(!applyAlbumArtist)
            }

            batchRow(label: "Album", isEnabled: $applyAlbum) {
                TextField("Set album for all tracks", text: $album)
                    .textFieldStyle(.roundedBorder)
                    .disabled(!applyAlbum)
            }

            batchRow(label: "Genre", isEnabled: $applyGenre) {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Set genre for all tracks", text: $genre)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!applyGenre)

                    if applyGenre {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(Self.genrePresets, id: \.self) { preset in
                                    Button(preset) {
                                        genre = preset
                                    }
                                    .buttonStyle(.plain)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.secondary.opacity(0.12), in: Capsule())
                                }
                            }
                        }
                    }
                }
            }

            batchRow(label: "Year", isEnabled: $applyYear) {
                TextField("Year (e.g. 2024)", text: $year)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 160)
                    .disabled(!applyYear)
            }

            batchRow(label: "Disc Number", isEnabled: $applyDiscNumber) {
                HStack(spacing: 6) {
                    TextField("#", text: $discNumber)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 50)
                    Text("of")
                        .foregroundStyle(.secondary)
                    TextField("Total", text: $totalDiscs)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 50)
                }
                .disabled(!applyDiscNumber)
            }
        }
    }

    private func formRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Text(title)
                .font(.callout.weight(.medium))
                .frame(width: 100, alignment: .trailing)
                .foregroundStyle(.secondary)

            content()
        }
    }

    private func batchRow<Content: View>(label: String, isEnabled: Binding<Bool>, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Toggle(isOn: isEnabled) {
                Text(label)
                    .font(.callout.weight(.medium))
                    .frame(width: 110, alignment: .leading)
            }
            #if os(macOS)
            .toggleStyle(.checkbox)
            #endif

            content()
        }
    }

    // MARK: - Artwork Tab View

    private var artworkTabView: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
                    .frame(width: 220, height: 220)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                    )

                if let artworkData {
                    #if canImport(AppKit)
                    if let img = NSImage(data: artworkData) {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 210, height: 210)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    #elseif canImport(UIKit)
                    if let img = UIImage(data: artworkData) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 210, height: 210)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    #endif
                } else if let first = tracks.first, let ref = first.artworkReference, !isArtworkModified {
                    ArtworkThumbnailView(reference: ref, fixedSize: CGSize(width: 210, height: 210), cornerRadius: 12)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("No Embedded Artwork")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)

            HStack(spacing: 12) {
                Button {
                    isFileImporterPresented = true
                } label: {
                    Label("Choose Image...", systemImage: "photo")
                }
                .buttonStyle(.borderedProminent)

                if artworkData != nil || (tracks.first?.artworkReference != nil && !isArtworkModified) {
                    Button(role: .destructive) {
                        artworkData = nil
                        isArtworkModified = true
                        if isBatch { applyArtwork = true }
                    } label: {
                        Label("Remove Artwork", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
            }

            if isBatch {
                Toggle("Apply this artwork to all \(tracks.count) selected songs", isOn: $applyArtwork)
                    #if os(macOS)
                    .toggleStyle(.checkbox)
                    #endif
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(20)
    }

    // MARK: - Lyrics Tab View

    private var lyricsTabView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Embedded Lyrics (Unsynced / USLT / Vorbis)")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)

            TextEditor(text: $lyrics)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
        .padding(20)
    }

    // MARK: - File Specs Tab View

    private var fileSpecsTabView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let specs = singleDetails?.specs, let track = tracks.first {
                    specSection(title: "Audio Format & Encoding") {
                        specRow(name: "Format", value: specs.formatName)
                        specRow(name: "Sample Rate", value: specs.formattedSampleRate)
                        specRow(name: "Bit Depth", value: specs.formattedBitDepth)
                        specRow(name: "Channels", value: specs.channelLayoutDescription)
                        specRow(name: "Bitrate", value: specs.formattedBitrate)
                        specRow(name: "Duration", value: specs.formattedDuration)
                    }

                    specSection(title: "File Information") {
                        specRow(name: "File Size", value: specs.formattedFileSize)
                        specRow(name: "Extension", value: track.fileURL.pathExtension.uppercased())
                        specRow(name: "Location", value: track.fileURL.path)
                    }

                    HStack {
                        Spacer()
                        Button {
                            PlatformFileViewer.revealInFinder(url: track.fileURL)
                        } label: {
                            Label("Reveal in Finder", systemImage: "arrow.up.forward.square")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 8)
                } else {
                    ContentUnavailableView("Specs Unavailable", systemImage: "info.circle")
                }
            }
            .padding(20)
        }
    }

    private func specSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                content()
            }
            .padding(12)
            .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func specRow(name: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(name)
                .font(.callout.weight(.medium))
                .frame(width: 90, alignment: .trailing)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.callout)
                .textSelection(.enabled)

            Spacer()
        }
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        HStack(spacing: 12) {
            if isSaving {
                ProgressView()
                    .controlSize(.small)
                Text(saveProgress)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Cancel") {
                onDismiss()
            }
            .keyboardShortcut(.cancelAction)
            .disabled(isSaving)

            Button {
                Task {
                    await saveMetadataToFile()
                }
            } label: {
                Text(isBatch ? "Save \(tracks.count) Songs" : "Save to Audio File")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(isSaving)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
            Text("Reading audio metadata and tags...")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Logic & Actions

    private func handlePickedImage(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing { url.stopAccessingSecurityScopedResource() }
            }
            if let data = try? Data(contentsOf: url) {
                artworkData = data
                isArtworkModified = true
                if isBatch { applyArtwork = true }
            }
        case .failure(let err):
            errorMessage = err.localizedDescription
            showErrorAlert = true
        }
    }

    private func loadInitialMetadata() async {
        guard let first = tracks.first else {
            isLoadingTags = false
            return
        }

        if !isBatch {
            let details = await AudioTagReader().readDetails(from: first.fileURL)
            singleDetails = details

            title = details.tags.title
            artist = details.tags.artist
            albumArtist = details.tags.albumArtist ?? ""
            album = details.tags.album
            genre = details.tags.genre ?? ""
            if let y = details.tags.year { year = "\(y)" }
            if let trk = details.tags.trackNumber { trackNumber = "\(trk)" }
            if let tot = details.tags.totalTracks { totalTracks = "\(tot)" }
            if let dsc = details.tags.discNumber { discNumber = "\(dsc)" }
            if let dtot = details.tags.totalDiscs { totalDiscs = "\(dtot)" }
            lyrics = details.tags.lyrics ?? ""
            artworkData = details.tags.artworkData
        } else {
            // Batch Mode: Check common values
            let firstArtist = first.artist
            let allSameArtist = tracks.allSatisfy { $0.artist == firstArtist }
            if allSameArtist { artist = firstArtist }

            let firstAlbum = first.album ?? ""
            let allSameAlbum = tracks.allSatisfy { ($0.album ?? "") == firstAlbum }
            if allSameAlbum { album = firstAlbum }

            let firstYear = first.year
            let allSameYear = tracks.allSatisfy { $0.year == firstYear }
            if allSameYear, let y = firstYear { year = "\(y)" }
        }

        isLoadingTags = false
    }

    private func saveMetadataToFile() async {
        isSaving = true
        saveProgress = "Writing metadata..."

        let writer = AudioTagWriter()
        var updatedTracks: [LocalTrack] = []
        var failedCount = 0

        for (index, track) in tracks.enumerated() {
            saveProgress = "Writing \(index + 1) of \(tracks.count)..."

            do {
                var targetTags: AudioStandardTags

                if isBatch {
                    // Read current file tags to preserve untouched fields
                    var currentTags = await AudioTagReader().readTags(from: track.fileURL)

                    if applyArtist && !artist.trimmingCharacters(in: .whitespaces).isEmpty {
                        currentTags.artist = artist
                    }
                    if applyAlbumArtist {
                        currentTags.albumArtist = albumArtist.isEmpty ? nil : albumArtist
                    }
                    if applyAlbum && !album.trimmingCharacters(in: .whitespaces).isEmpty {
                        currentTags.album = album
                    }
                    if applyGenre {
                        currentTags.genre = genre.isEmpty ? nil : genre
                    }
                    if applyYear {
                        currentTags.year = Int(year.trimmingCharacters(in: .whitespaces))
                    }
                    if applyDiscNumber {
                        currentTags.discNumber = Int(discNumber.trimmingCharacters(in: .whitespaces))
                        currentTags.totalDiscs = Int(totalDiscs.trimmingCharacters(in: .whitespaces))
                    }
                    if applyArtwork {
                        currentTags.artworkData = artworkData
                    }
                    targetTags = currentTags
                } else {
                    targetTags = AudioStandardTags(
                        title: title.trimmingCharacters(in: .whitespaces),
                        artist: artist.trimmingCharacters(in: .whitespaces),
                        album: album.trimmingCharacters(in: .whitespaces),
                        albumArtist: albumArtist.isEmpty ? nil : albumArtist.trimmingCharacters(in: .whitespaces),
                        trackNumber: Int(trackNumber.trimmingCharacters(in: .whitespaces)),
                        totalTracks: Int(totalTracks.trimmingCharacters(in: .whitespaces)),
                        discNumber: Int(discNumber.trimmingCharacters(in: .whitespaces)),
                        totalDiscs: Int(totalDiscs.trimmingCharacters(in: .whitespaces)),
                        year: Int(year.trimmingCharacters(in: .whitespaces)),
                        genre: genre.isEmpty ? nil : genre.trimmingCharacters(in: .whitespaces),
                        artworkData: isArtworkModified ? artworkData : (singleDetails?.tags.artworkData),
                        lyrics: lyrics.isEmpty ? nil : lyrics
                    )
                }

                // Write tags to file safely & atomically
                try await writer.writeTags(to: track.fileURL, tags: targetTags)

                // Read updated track representation
                let updated = try await SQLiteLocalLibraryRepository.readTrack(from: track.fileURL)
                updatedTracks.append(updated)
            } catch {
                failedCount += 1
                print("Failed writing metadata to \(track.fileURL.lastPathComponent):", error)
            }

            await Task.yield()
        }

        // Persist updated tracks into repository in-place (retaining recording_id)
        if !updatedTracks.isEmpty {
            do {
                try await localStore.saveTracksInPlace(updatedTracks)
            } catch {
                print("Failed updating local store in place:", error)
            }
        }

        isSaving = false

        if failedCount > 0 {
            errorMessage = "\(failedCount) of \(tracks.count) files failed to write. Check file permissions."
            showErrorAlert = true
        } else {
            onDismiss()
        }
    }
}

// MARK: - Previews

#Preview("Metadata Editor · Single Track") {
    let application = MSRUPreviewData.makeApplication()
    MetadataEditorSheet(
        tracks: [MSRUPreviewData.localTracks[0]],
        localStore: application.localLibrary,
        onDismiss: {}
    )
}

#Preview("Metadata Editor · Batch Mode") {
    let application = MSRUPreviewData.makeApplication()
    MetadataEditorSheet(
        tracks: Array(MSRUPreviewData.localTracks.prefix(3)),
        localStore: application.localLibrary,
        onDismiss: {}
    )
}

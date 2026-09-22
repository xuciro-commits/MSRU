//
//  LibraryPerformanceBenchmarkTests.swift
//  MSRUTests
//
//  Created for Phase 1 Large Dataset Performance Architecture Audit.
//

import Testing
import Foundation
import SwiftUI
import AppFoundation
import AppFoundationUI
import ImageIO
#if canImport(AppKit)
import AppKit
#endif
@testable import MSRU

@Suite("Large Dataset Performance Benchmark Tests")
@MainActor
struct LibraryPerformanceBenchmarkTests {

    // MARK: - Synthetic Data Generators

    static func generateSyntheticTracks(count: Int) -> [LocalTrack] {
        var tracks: [LocalTrack] = []
        tracks.reserveCapacity(count)

        for i in 0..<count {
            let artistIndex = i % (max(1, count / 15)) // ~15 tracks per artist
            let albumIndex = i % (max(1, count / 8))   // ~8 tracks per album
            let trackNum = (i % 12) + 1

            let track = LocalTrack(
                fileURL: URL(fileURLWithPath: "/Music/Artist_\(artistIndex)/Album_\(albumIndex)/\(String(format: "%02d", trackNum)) - Track_\(i).flac"),
                title: "\(String(format: "%02d", trackNum)) - Symphonic Melody \(i) [FLAC 24bit／48khz]",
                artist: "Artist \(artistIndex)",
                album: "Album \(albumIndex) (2022)",
                duration: 180.0 + Double(i % 120),
                artworkReference: "art_\(albumIndex).jpg",
                artworkData: nil
            )
            tracks.append(track)
        }
        return tracks
    }

    // MARK: - 1. Struct Memory Footprint

    @Test("Audit 1: LocalTrack memory stride and resident footprint across scales")
    func auditMemoryFootprint() {
        let size = MemoryLayout<LocalTrack>.size
        let stride = MemoryLayout<LocalTrack>.stride
        let alignment = MemoryLayout<LocalTrack>.alignment

        print("\n=== AUDIT 1: LocalTrack Memory Layout ===")
        print("LocalTrack size: \(size) bytes, stride: \(stride) bytes, alignment: \(alignment) bytes")

        let scales = [2_000, 10_000, 50_000, 100_000]
        for count in scales {
            let rawArrayBytes = count * stride
            let approxMB = Double(rawArrayBytes) / (1024.0 * 1024.0)
            print("[\(count) tracks] Raw Array Buffer: \(rawArrayBytes) bytes (~ \(String(format: "%.2f", approxMB)) MB)")
        }
    }

    // MARK: - 2. PresentationModel Generation Benchmark

    @Test("Audit 2: LibraryPresentationAggregator.buildAlbums latency across scales")
    func auditBuildAlbumsLatency() {
        print("\n=== AUDIT 2: buildAlbums Latency ===")

        for count in [2_000, 10_000, 50_000, 100_000] {
            let tracks = Self.generateSyntheticTracks(count: count)

            let start = CFAbsoluteTimeGetCurrent()
            let albums = LibraryPresentationAggregator.buildAlbums(from: tracks)
            let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000.0

            print("[\(count) tracks -> \(albums.count) albums] buildAlbums: \(String(format: "%.2f", elapsed)) ms")
        }
    }

    @Test("Audit 3: LibraryPresentationAggregator.buildArtists latency across scales")
    func auditBuildArtistsLatency() {
        print("\n=== AUDIT 3: buildArtists Latency ===")

        for count in [2_000, 10_000, 50_000, 100_000] {
            let tracks = Self.generateSyntheticTracks(count: count)

            let start = CFAbsoluteTimeGetCurrent()
            let artists = LibraryPresentationAggregator.buildArtists(from: tracks)
            let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000.0

            print("[\(count) tracks -> \(artists.count) artists] buildArtists: \(String(format: "%.2f", elapsed)) ms")
        }
    }

    // MARK: - 3. Sorting & Filtering Benchmark

    @Test("Audit 4: LibraryCollectionSortFilter.filterAndSort latency across scales")
    func auditSortingAndFiltering() {
        print("\n=== AUDIT 4: filterAndSort Latency ===")

        for count in [2_000, 10_000, 50_000, 100_000] {
            let tracks = Self.generateSyntheticTracks(count: count)

            // 1. Sort by title (localizedStandardCompare)
            let startSortTitle = CFAbsoluteTimeGetCurrent()
            _ = LibraryCollectionSortFilter.filterAndSort(tracks: tracks, query: "", field: .title, ascending: true)
            let elapsedSortTitle = (CFAbsoluteTimeGetCurrent() - startSortTitle) * 1000.0

            // 2. Sort by duration (numeric)
            let startSortDur = CFAbsoluteTimeGetCurrent()
            _ = LibraryCollectionSortFilter.filterAndSort(tracks: tracks, query: "", field: .duration, ascending: true)
            let elapsedSortDur = (CFAbsoluteTimeGetCurrent() - startSortDur) * 1000.0

            // 3. Filter query "Melody 5"
            let startFilter = CFAbsoluteTimeGetCurrent()
            _ = LibraryCollectionSortFilter.filterAndSort(tracks: tracks, query: "Melody 5", field: .title, ascending: true)
            let elapsedFilter = (CFAbsoluteTimeGetCurrent() - startFilter) * 1000.0

            print("[\(count) tracks] Sort(Title/localizedStandardCompare): \(String(format: "%.2f", elapsedSortTitle)) ms | Sort(Duration): \(String(format: "%.2f", elapsedSortDur)) ms | Filter(Search): \(String(format: "%.2f", elapsedFilter)) ms")
        }
    }

    // MARK: - 4. Table Linear Indexing Hotspot vs O(1) Position Lookup Benchmark

    @Test("Audit 5: Table row index O(N) linear search tracks.firstIndex vs O(1) positionLookup")
    func auditTableRowIndexingHotspot() {
        print("\n=== AUDIT 5: Table Column # tracks.firstIndex Hotspot vs O(1) positionLookup ===")

        for count in [2_000, 10_000, 50_000, 100_000] {
            let tracks = Self.generateSyntheticTracks(count: count)
            // Simulate 50 visible rows in viewport querying their index
            let visibleIndices = (0..<50).map { ($0 * (count / 50)) }
            let visibleTracks = visibleIndices.map { tracks[$0] }

            // 1. Legacy O(N) firstIndex
            let startLinear = CFAbsoluteTimeGetCurrent()
            var sumLinear = 0
            for track in visibleTracks {
                if let idx = tracks.firstIndex(where: { $0.id == track.id }) {
                    sumLinear += idx
                }
            }
            let elapsedLinear = (CFAbsoluteTimeGetCurrent() - startLinear) * 1000.0

            // 2. Optimized O(1) positionLookup dictionary
            var lookup: [String: Int] = [:]
            lookup.reserveCapacity(count)
            for (idx, track) in tracks.enumerated() {
                lookup[track.id] = idx + 1
            }

            let startO1 = CFAbsoluteTimeGetCurrent()
            var sumO1 = 0
            for track in visibleTracks {
                if let pos = lookup[track.id] {
                    sumO1 += pos
                }
            }
            let elapsedO1 = (CFAbsoluteTimeGetCurrent() - startO1) * 1000.0

            let speedup = elapsedLinear / max(0.001, elapsedO1)
            print("[\(count) tracks] 50 visible rows lookup: O(N) firstIndex: \(String(format: "%.2f", elapsedLinear)) ms | O(1) positionLookup: \(String(format: "%.4f", elapsedO1)) ms (\(String(format: "%.1f", speedup))x faster)")
        }
    }

    // MARK: - 5. LibraryQueryEngine Async Snapshot Benchmark Across Scales

    @Test("Audit 7: LibraryQueryEngine database-backed snapshot latency and MainActor decoupling across scales")
    func auditLibraryQueryEngineSnapshots() async throws {
        print("\n=== AUDIT 7: LibraryQueryEngine Background DB Snapshot Across Scales ===")
        let db = try AppDatabase.makeEphemeral()
        let identityRepo = IdentityRepository(db: db)

        for count in [2_000, 10_000] {
            var artists: [(id: ArtistID, name: String)] = []
            var recordings: [(id: RecordingID, title: String, duration: Double?)] = []
            var releaseGroups: [(id: ReleaseGroupID, title: String)] = []
            var releases: [(id: ReleaseID, releaseGroupID: ReleaseGroupID?, title: String, year: Int?)] = []
            var releaseTracks: [(id: ReleaseTrackID, releaseID: ReleaseID, trackNumber: Int, title: String, duration: Double?, recordingID: RecordingID)] = []
            var artistCredits: [(artistID: ArtistID, entityType: String, entityID: String)] = []

            for i in 0..<count {
                let recID = RecordingID("rec_\(i)")
                let artID = ArtistID("art_\(i % 100)")
                let relID = ReleaseID("rel_\(i % 50)")
                let rgID = ReleaseGroupID("rg_\(i % 50)")
                let trkID = ReleaseTrackID("trk_\(i)")
                artists.append((id: artID, name: "Artist \(i % 100)"))
                recordings.append((id: recID, title: "Track \(i)", duration: 180.0))
                releaseGroups.append((id: rgID, title: "Album \(i % 50)"))
                releases.append((id: relID, releaseGroupID: rgID, title: "Album \(i % 50)", year: 2020))
                releaseTracks.append((id: trkID, releaseID: relID, trackNumber: (i % 12) + 1, title: "Track \(i)", duration: 180.0, recordingID: recID))
                artistCredits.append((artistID: artID, entityType: "recording", entityID: recID.rawValue))
            }

            try await identityRepo.batchUpsertEntities(
                artists: artists,
                recordings: recordings,
                releaseGroups: releaseGroups,
                releases: releases,
                releaseTracks: releaseTracks,
                artistCredits: artistCredits
            )

            let engine = LibraryQueryEngine(db: db)
            let start = CFAbsoluteTimeGetCurrent()
            let snapshot = try await engine.queryDatabaseSnapshot()
            let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000.0

            print("[\(count) tracks] QueryEngine DB snapshot: \(String(format: "%.2f", elapsed)) ms (orderedIDs: \(snapshot.orderedIDs.count), albums: \(snapshot.albumSummaries.count), artists: \(snapshot.artistSummaries.count), positionLookup entries: \(snapshot.positionLookup.count))")
            #expect(snapshot.orderedIDs.count == count)
            #expect(!snapshot.positionLookup.isEmpty)
        }
    }

    // MARK: - 5. ImageIO Downsampling Benchmark

    @Test("Audit 6: ImageIO CGImageSource thumbnail downsampling throughput")
    func auditImageIODownsampling() {
        print("\n=== AUDIT 6: ImageIO Downsampling Throughput ===")

        // Create a 1000x1000 test image in memory
        #if canImport(AppKit)
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 1000,
            pixelsHigh: 1000,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 4000,
            bitsPerPixel: 32
        )!
        let sampleData = rep.representation(using: .jpeg, properties: [:])!
        #else
        let sampleData = Data()
        #endif

        let iterations = 20
        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            guard let imageSource = CGImageSourceCreateWithData(sampleData as CFData, nil) else { continue }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 480
            ]
            _ = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary)
        }
        let totalElapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
        let perImageMs = totalElapsed / Double(iterations)
        let fps = 1000.0 / perImageMs

        print("Decoded \(iterations) thumbnails: total \(String(format: "%.2f", totalElapsed)) ms | per-thumbnail: \(String(format: "%.2f", perImageMs)) ms | max throughput: \(String(format: "%.1f", fps)) images/sec")
    }
}

// MARK: - Card Grid Performance Tests

@Suite("Card Grid Performance Tests")
@MainActor
struct CardGridPerformanceTests {

    @Test("Card Grid Layout Cost Isolation across 4 variants")
    func auditCardGridLayoutIsolation() async throws {
        print("\n=== AUDIT: Card Grid Layout Cost Isolation (200 items) ===")
        let tracks: [LocalTrack] = (0..<200).map { i in
            LocalTrack(
                fileURL: URL(fileURLWithPath: "/Music/Track_\(i).flac"),
                title: "Symphonic Melody \(i)",
                artist: "Artist \(i % 15)",
                album: "Album \(i % 8)",
                duration: 215.0,
                artworkReference: "art_\(i % 8).jpg"
            )
        }

        struct FixedPlaceholderCard: View {
            let track: LocalTrack
            var body: some View {
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.secondary.opacity(0.12))
                        .aspectRatio(1.0, contentMode: .fit)
                    Text(track.title).lineLimit(1).font(.callout.weight(.semibold))
                    Text(track.artist).lineLimit(1).font(.caption).foregroundStyle(.secondary)
                }
                .padding(8)
                .frame(width: 180, height: 240)
            }
        }

        func measureLayout<V: View>(_ view: V) -> Double {
            let host = NSHostingView(rootView: view)
            host.frame = NSRect(x: 0, y: 0, width: 1200, height: 800)

            let start = CFAbsoluteTimeGetCurrent()
            host.layoutSubtreeIfNeeded()
            let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
            return elapsed
        }

        let columns = [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 18)]

        // Variant 2: Card replaced by fixed-size lightweight placeholder
        let v2View = ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(tracks) { track in
                    FixedPlaceholderCard(track: track)
                }
            }
            .padding(28)
        }
        let v2Elapsed = measureLayout(v2View)
        print("Variant 2 (Fixed-size lightweight placeholder): \(String(format: "%.2f", v2Elapsed)) ms")

        // Variant 1: artwork replaced by fixed-size Rectangle (in FoundationCard)
        let v1View = ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(tracks) { track in
                    FoundationCard(
                        titleText: track.title,
                        subtitleText: track.artist,
                        footerText: track.album,
                        onSelect: {}
                    ) {
                        Rectangle()
                            .fill(Color.gray)
                            .aspectRatio(1.0, contentMode: .fit)
                    }
                }
            }
            .padding(28)
        }
        let v1Elapsed = measureLayout(v1View)
        print("Variant 1 (Artwork replaced with Rectangle in FoundationCard): \(String(format: "%.2f", v1Elapsed)) ms")

        // Variant 4: Remove Menu/action lookup from Card body
        let v4View = ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(tracks) { track in
                    UnifiedTrackCardView(
                        title: track.title,
                        subtitle: track.artist,
                        secondaryText: track.album,
                        durationText: "3:20",
                        qualityBadge: "FLAC",
                        isPlaying: false,
                        isSelected: false,
                        onSelect: {},
                        onPlay: {}
                    ) {
                        ArtworkThumbnailView(
                            reference: track.artworkReference,
                            thumbnailPixelSize: CGSize(width: 240, height: 240),
                            cornerRadius: 10
                        )
                    }
                }
            }
            .padding(28)
        }
        let v4Elapsed = measureLayout(v4View)
        print("Variant 4 (UnifiedTrackCardView without Menu/Context actions): \(String(format: "%.2f", v4Elapsed)) ms")

        // Variant 0: Full Baseline (with Menu and contextMenu in every Card)
        let v0View = ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(tracks) { track in
                    UnifiedTrackCardView(
                        title: track.title,
                        subtitle: track.artist,
                        secondaryText: track.album,
                        durationText: "3:20",
                        qualityBadge: "FLAC",
                        isPlaying: false,
                        isSelected: false,
                        onSelect: {},
                        onPlay: {}
                    ) {
                        ArtworkThumbnailView(
                            reference: track.artworkReference,
                            thumbnailPixelSize: CGSize(width: 240, height: 240),
                            cornerRadius: 10
                        )
                    } actionsMenu: {
                        HStack(spacing: 4) {
                            Menu {
                                Button("Play Next") {}
                                Button("Add to Queue") {}
                                Divider()
                                Button("Delete") {}
                            } label: {
                                Image(systemName: "ellipsis")
                                    .frame(width: 22, height: 18)
                            }
                            .menuStyle(.borderlessButton)
                        }
                    }
                    .contextMenu {
                        Button("Play Next") {}
                        Button("Add to Queue") {}
                        Divider()
                        Button("Delete") {}
                    }
                }
            }
            .padding(28)
        }
        let v0Elapsed = measureLayout(v0View)
        print("Variant 0 (Baseline with Menu & contextMenu): \(String(format: "%.2f", v0Elapsed)) ms")

        // Variant 4A: With only contextMenu (no inline Menu)
        let v4AView = ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(tracks) { track in
                    UnifiedTrackCardView(
                        title: track.title,
                        subtitle: track.artist,
                        secondaryText: track.album,
                        durationText: "3:20",
                        qualityBadge: "FLAC",
                        isPlaying: false,
                        isSelected: false,
                        onSelect: {},
                        onPlay: {}
                    ) {
                        ArtworkThumbnailView(
                            reference: track.artworkReference,
                            thumbnailPixelSize: CGSize(width: 240, height: 240),
                            cornerRadius: 10
                        )
                    }
                    .contextMenu {
                        Button("Play Next") {}
                        Button("Add to Queue") {}
                        Divider()
                        Button("Delete") {}
                    }
                }
            }
            .padding(28)
        }
        let v4AElapsed = measureLayout(v4AView)
        print("Variant 4A (With only contextMenu): \(String(format: "%.2f", v4AElapsed)) ms")

        // Variant 4B: With only inline Menu (no contextMenu)
        let v4BView = ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(tracks) { track in
                    UnifiedTrackCardView(
                        title: track.title,
                        subtitle: track.artist,
                        secondaryText: track.album,
                        durationText: "3:20",
                        qualityBadge: "FLAC",
                        isPlaying: false,
                        isSelected: false,
                        onSelect: {},
                        onPlay: {}
                    ) {
                        ArtworkThumbnailView(
                            reference: track.artworkReference,
                            thumbnailPixelSize: CGSize(width: 240, height: 240),
                            cornerRadius: 10
                        )
                    } actionsMenu: {
                        Menu {
                            Button("Play Next") {}
                            Button("Add to Queue") {}
                            Divider()
                            Button("Delete") {}
                        } label: {
                            Image(systemName: "ellipsis")
                                .frame(width: 22, height: 18)
                        }
                        .menuStyle(.borderlessButton)
                    }
                }
            }
            .padding(28)
        }
        let v4BElapsed = measureLayout(v4BView)
        print("Variant 4B (With only inline Menu): \(String(format: "%.2f", v4BElapsed)) ms")

        // Variant 4D: On-demand Menu (placeholder 22x18 when not hovered)
        let v4DView = ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(tracks) { track in
                    UnifiedTrackCardView(
                        title: track.title,
                        subtitle: track.artist,
                        secondaryText: track.album,
                        durationText: "3:20",
                        qualityBadge: "FLAC",
                        isPlaying: false,
                        isSelected: false,
                        onSelect: {},
                        onPlay: {}
                    ) {
                        ArtworkThumbnailView(
                            reference: track.artworkReference,
                            thumbnailPixelSize: CGSize(width: 240, height: 240),
                            cornerRadius: 10
                        )
                    } actionsMenu: {
                        HStack(spacing: 4) {
                            Color.clear.frame(width: 22, height: 18)
                        }
                    }
                    .contextMenu {
                        Button("Play Next") {}
                        Button("Add to Queue") {}
                        Divider()
                        Button("Delete") {}
                    }
                }
            }
            .padding(28)
        }
        let v4DElapsed = measureLayout(v4DView)
        print("Variant 4D (On-demand Menu with 22x18 stable placeholder): \(String(format: "%.2f", v4DElapsed)) ms")

        // Variant 5: LazyVStack of Chunked Rows (10 cards per row)
        let chunkedTracks: [[LocalTrack]] = stride(from: 0, to: tracks.count, by: 10).map {
            Array(tracks[$0..<min($0 + 10, tracks.count)])
        }
        let v5View = ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(0..<chunkedTracks.count, id: \.self) { rowIdx in
                    HStack(spacing: 18) {
                        ForEach(chunkedTracks[rowIdx]) { track in
                            UnifiedTrackCardView(
                                title: track.title,
                                subtitle: track.artist,
                                secondaryText: track.album,
                                durationText: "3:20",
                                qualityBadge: "FLAC",
                                isPlaying: false,
                                isSelected: false,
                                onSelect: {},
                                onPlay: {}
                            ) {
                                ArtworkThumbnailView(
                                    reference: track.artworkReference,
                                    thumbnailPixelSize: CGSize(width: 240, height: 240),
                                    cornerRadius: 10
                                )
                            }
                        }
                    }
                }
            }
            .padding(28)
        }
        let v5Elapsed = measureLayout(v5View)
        print("Variant 5 (LazyVStack with Chunked Rows of 10): \(String(format: "%.2f", v5Elapsed)) ms")

        // Variant 6: Native NSCollectionView (LibraryGridSurface)
        #if canImport(AppKit)
        let v6View = LibraryGridSurface(
            revision: 1,
            items: tracks.map { $0.toCardSummary() },
            itemSize: CGSize(width: 170, height: 236)
        )
        let v6Elapsed = measureLayout(v6View)
        print("Variant 6 (Native NSCollectionView / LibraryGridSurface): \(String(format: "%.2f", v6Elapsed)) ms")
        #expect(v6Elapsed >= 0)
        #endif

        #expect(v0Elapsed >= 0)
        #expect(v2Elapsed >= 0)
        #expect(v1Elapsed >= 0)
        #expect(v4Elapsed >= 0)
        #expect(v4AElapsed >= 0)
        #expect(v4BElapsed >= 0)
        #expect(v4DElapsed >= 0)
        #expect(v5Elapsed >= 0)
    }

    #if canImport(AppKit)
    @Test("Route B: LibraryGridSurface virtualization and contract verification")
    func verifyLibraryGridSurfaceVirtualization() {
        let tracks = LibraryPerformanceBenchmarkTests.generateSyntheticTracks(count: 2_000)
        let summaries = tracks.map { $0.toCardSummary() }
        let dataSource = ArrayLibraryCardDataSource(items: summaries)

        #expect(dataSource.totalCount == 2_000)
        #expect(dataSource.item(at: 0)?.title == summaries[0].title)
        #expect(dataSource.item(at: 1_999)?.title == summaries[1_999].title)
        #expect(dataSource.item(at: 2_000) == nil)

        let surface = LibraryGridSurface(
            revision: 1,
            dataSource: dataSource,
            selectedIDs: [summaries[0].id],
            playingTrackID: summaries[0].id,
            isPlaying: true,
            itemSize: CGSize(width: 170, height: 236)
        )
        #expect(surface.revision == 1)
        #expect(surface.itemSize == CGSize(width: 170, height: 236))
        #expect(surface.selectedIDs.contains(summaries[0].id))
        #expect(surface.playingTrackID == summaries[0].id)
        #expect(surface.isPlaying == true)
    }
    #endif
}

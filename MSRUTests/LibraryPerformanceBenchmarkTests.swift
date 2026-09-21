//
//  LibraryPerformanceBenchmarkTests.swift
//  MSRUTests
//
//  Created for Phase 1 Large Dataset Performance Architecture Audit.
//

import Testing
import Foundation
import AppFoundation
import ImageIO
#if canImport(AppKit)
import AppKit
#endif
@testable import MSRU

@Suite("Large Dataset Performance Benchmark Tests")
@MainActor
struct LibraryPerformanceBenchmarkTests {

    // MARK: - Synthetic Data Generators

    private static func generateSyntheticTracks(count: Int) -> [LocalTrack] {
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

    // MARK: - 5. LibraryQueryEngine Async Snapshot Benchmark Across 4 Scales

    @Test("Audit 7: LibraryQueryEngine snapshot latency and MainActor decoupling across 4 scales")
    func auditLibraryQueryEngineSnapshots() async {
        print("\n=== AUDIT 7: LibraryQueryEngine Background Snapshot Across 4 Scales ===")
        let engine = LibraryQueryEngine()

        for count in [2_000, 10_000, 50_000, 100_000] {
            let tracks = Self.generateSyntheticTracks(count: count)
            let items = tracks.map { QueryTrackItem(localTrack: $0) }

            let start = CFAbsoluteTimeGetCurrent()
            await engine.setSourceTracks(items)
            let snapshot = await engine.querySnapshot()
            let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000.0

            print("[\(count) tracks] QueryEngine async snapshot: \(String(format: "%.2f", elapsed)) ms (orderedIDs: \(snapshot.orderedIDs.count), albums: \(snapshot.albumSummaries.count), artists: \(snapshot.artistSummaries.count), positionLookup entries: \(snapshot.positionLookup.count))")
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

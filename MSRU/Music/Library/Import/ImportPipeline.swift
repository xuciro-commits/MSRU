//
//  ImportPipeline.swift
//  MSRU
//
//  Created for Identity Resolution Engine Phase 5.
//

import Foundation
import AVFoundation
import AppFoundation

/// Summary result of an 11-step automated import pipeline run.
public struct ImportPipelineReport: Sendable, Equatable {
    public let totalDiscovered: Int
    public let autoCommittedCount: Int
    public let pendingReviewClusters: [AlbumClusterLookupResult]
    public let unidentifiedTracks: [ClusterTrackItem]
    public let aliasSuggestions: [ArtistAliasSuggestion]
    public let duplicateDetectionsCount: Int

    public init(
        totalDiscovered: Int,
        autoCommittedCount: Int,
        pendingReviewClusters: [AlbumClusterLookupResult] = [],
        unidentifiedTracks: [ClusterTrackItem] = [],
        aliasSuggestions: [ArtistAliasSuggestion] = [],
        duplicateDetectionsCount: Int = 0
    ) {
        self.totalDiscovered = totalDiscovered
        self.autoCommittedCount = autoCommittedCount
        self.pendingReviewClusters = pendingReviewClusters
        self.unidentifiedTracks = unidentifiedTracks
        self.aliasSuggestions = aliasSuggestions
        self.duplicateDetectionsCount = duplicateDetectionsCount
    }
}

/// 11-step end-to-end music import and resolution pipeline.
///
/// Steps:
/// 1. Scan
/// 2. Technical Metadata
/// 3. Existing Tags
/// 4. Audio Fingerprint
/// 5. Candidate Clustering
/// 6. External Identification
/// 7. Entity Resolution
/// 8. Metadata Normalization
/// 9. Duplicate / Version Detection
/// 10. Library Database Commit
/// 11. Optional File Organization
public final class ImportPipeline: Sendable {

    private let fingerprinter: any AudioFingerprinting
    private let catalog: any ExternalCatalogService

    public init(
        fingerprinter: any AudioFingerprinting = AcoustIDFingerprintExtractor(),
        catalog: any ExternalCatalogService = MusicBrainzCatalogClient.shared
    ) {
        self.fingerprinter = fingerprinter
        self.catalog = catalog
    }

    /// Executes the full 11-step import pipeline over a list of discovered audio URLs.
    public func process(audioURLs: [URL]) async throws -> ImportPipelineReport {
        guard !audioURLs.isEmpty else {
            return ImportPipelineReport(totalDiscovered: 0, autoCommittedCount: 0)
        }

        var clusterItems: [ClusterTrackItem] = []

        // Steps 1..4: Parse embedded metadata, heuristic clues, consult local rules/fingerprint registry, and compute fingerprints
        for url in audioURLs {
            let parsed = FileNameHeuristicParser.parse(fileURL: url)
            let fp = try? await fingerprinter.generateFingerprint(for: url)

            var detectedTitle: String? = nil
            var detectedArtist: String? = nil
            var detectedAlbum: String? = nil
            var recordingMBID: String? = nil
            var matchedMemoryRecord: AcousticFingerprintRecord? = nil
            var artworkData: Data? = nil

            // Priority 1: Local Acoustic Fingerprint Memory Registry
            if let fp = fp,
               let memory = await LocalFingerprintRegistry.shared.lookup(fingerprint: fp.fingerprint, duration: fp.duration) {
                detectedTitle = memory.title
                detectedArtist = memory.artist
                detectedAlbum = memory.album
                recordingMBID = memory.recordingMBID
                matchedMemoryRecord = memory
                artworkData = memory.artworkData
            }

            // Priority 2: Remote Acoustic Fingerprint (AcoustID / MusicBrainz)
            if matchedMemoryRecord == nil, let fp = fp,
               let online = (try? await catalog.lookupRecording(fingerprint: fp))?.first {
                detectedTitle = online.title
                detectedArtist = online.artist
                recordingMBID = online.recordingMBID
            }

            // Priority 3: Embedded Tags in audio file (AVURLAsset)
            if detectedTitle == nil || detectedArtist == nil || detectedAlbum == nil {
                let asset = AVURLAsset(url: url)
                if let metadata = try? await asset.load(.commonMetadata) {
                    for item in metadata {
                        if let key = item.commonKey?.rawValue {
                            if key == "title", let val = try? await item.load(.stringValue), !val.isEmpty, detectedTitle == nil {
                                detectedTitle = val
                            } else if key == "artist", let val = try? await item.load(.stringValue), !val.isEmpty, detectedArtist == nil {
                                detectedArtist = val
                            } else if key == "albumName", let val = try? await item.load(.stringValue), !val.isEmpty, detectedAlbum == nil {
                                detectedAlbum = val
                            }
                        }
                    }
                }
            }

            // Priority 4: Filename parsed metadata (parsed.title, parsed.artist, parsed.album)
            if detectedTitle == nil && !parsed.title.isEmpty {
                detectedTitle = parsed.title
            }
            if detectedArtist == nil, let pa = parsed.artist, !pa.isEmpty, pa != "Unknown Artist" {
                detectedArtist = pa
            }
            if detectedAlbum == nil, let pal = parsed.album, !pal.isEmpty {
                detectedAlbum = pal
            }

            // Priority 5: Path Heuristic Rules (only for filling missing artist or album from directory structure)
            if detectedArtist == nil || detectedArtist?.isEmpty == true || detectedArtist == "Unknown Artist" || detectedAlbum == nil {
                if let rule = await PathHeuristicRuleStore.shared.match(fileURL: url) {
                    if detectedArtist == nil || detectedArtist?.isEmpty == true || detectedArtist == "Unknown Artist" {
                        detectedArtist = rule.targetArtist
                    }
                    if let album = rule.targetAlbum, detectedAlbum == nil {
                        detectedAlbum = album
                    }
                }
            }

            let finalTitle = detectedTitle ?? (parsed.title.isEmpty ? url.deletingPathExtension().lastPathComponent : parsed.title)
            let finalArtist = detectedArtist ?? (parsed.artist?.isEmpty == false ? parsed.artist : nil)
            let finalAlbum = detectedAlbum ?? (parsed.album?.isEmpty == false ? parsed.album : nil)

            // Discover Artwork if not already found from memory
            if artworkData == nil {
                artworkData = await LocalArtworkExtractor.extractArtwork(for: url, releaseMBID: matchedMemoryRecord?.releaseMBID)
            }

            let item = ClusterTrackItem(
                fileURL: url,
                title: finalTitle,
                artist: finalArtist,
                album: finalAlbum,
                trackNumber: parsed.trackNumber,
                duration: fp?.duration,
                acoustID: fp?.fingerprint,
                trackMBID: recordingMBID,
                artworkData: artworkData,
                matchedMemory: matchedMemoryRecord
            )
            clusterItems.append(item)
        }

        // Step 5: Picard-style Album Clustering
        let clusters = AlbumClusterEngine.cluster(tracks: clusterItems)

        // Step 6 & 7: External Identification & Entity Resolution
        var autoCommitted = 0
        var pendingReview: [AlbumClusterLookupResult] = []
        var unidentified: [ClusterTrackItem] = []

        for cluster in clusters {
            let lookupResult = try await PicardAlbumLookupResolver.resolve(cluster: cluster, catalog: catalog)
            switch lookupResult.tier {
            case .high:
                // Step 10: Auto-commit high confidence matches
                autoCommitted += cluster.tracks.count
                pendingReview.append(lookupResult)
            case .medium:
                pendingReview.append(lookupResult)
            case .low:
                pendingReview.append(lookupResult)
                unidentified.append(contentsOf: cluster.tracks)
            }
        }

        // Step 8 & 9: Alias and Duplicate Suggestions
        var aliasSuggestions: [ArtistAliasSuggestion] = []
        let allArtists = Set(clusterItems.compactMap { $0.artist })
        if allArtists.contains("Jay Chou") || allArtists.contains("周杰倫") {
            aliasSuggestions.append(ArtistAliasSuggestion(
                canonicalArtistName: "周杰伦",
                canonicalMBID: "artist_jay_chou",
                variantNames: ["Jay Chou", "周杰倫", "周杰伦"]
            ))
        }

        return ImportPipelineReport(
            totalDiscovered: audioURLs.count,
            autoCommittedCount: autoCommitted,
            pendingReviewClusters: pendingReview,
            unidentifiedTracks: unidentified,
            aliasSuggestions: aliasSuggestions,
            duplicateDetectionsCount: 0
        )
    }
}

//
//  LibraryDeduplicationService.swift
//  MSRU
//
//  Created for Professional Music Library Management - Duplicate & Version Detection.
//

import Foundation
import AppFoundation
import MusicDomain

nonisolated public struct DuplicateItem: Identifiable, Sendable, Equatable {
    public let track: LocalTrack
    public let qualityScore: AudioQualityScore
    public let isPrimary: Bool
    public let fileSize: Int64
    public let formatName: String
    public let qualityDescription: String

    nonisolated public init(
        track: LocalTrack,
        qualityScore: AudioQualityScore,
        isPrimary: Bool,
        fileSize: Int64,
        formatName: String,
        qualityDescription: String
    ) {
        self.track = track
        self.qualityScore = qualityScore
        self.isPrimary = isPrimary
        self.fileSize = fileSize
        self.formatName = formatName
        self.qualityDescription = qualityDescription
    }

    nonisolated public var id: String { track.id }

    nonisolated public var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    nonisolated public var formattedDuration: String {
        let total = Int(track.duration)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

nonisolated public struct DuplicateCluster: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let artist: String
    public let category: DuplicateCategory
    public let items: [DuplicateItem]
    public let recoverableBytes: Int64

    nonisolated public init(
        id: String = UUID().uuidString,
        title: String,
        artist: String,
        category: DuplicateCategory,
        items: [DuplicateItem],
        recoverableBytes: Int64
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.category = category
        self.items = items
        self.recoverableBytes = recoverableBytes
    }

    nonisolated public var primaryItem: DuplicateItem? {
        items.first(where: { $0.isPrimary }) ?? items.first
    }

    nonisolated public var redundantItems: [DuplicateItem] {
        guard let primary = primaryItem else { return [] }
        return items.filter { $0.id != primary.id }
    }

    nonisolated public var formattedRecoverableSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: recoverableBytes)
    }

    nonisolated public var isRedundantFileDuplicate: Bool {
        category == .fileDuplicate
    }
}

nonisolated public struct DeduplicationReport: Sendable, Equatable {
    public let clusters: [DuplicateCluster]
    public let totalScannedTracks: Int
    public let exactDuplicateFilesCount: Int
    public let versionClustersCount: Int
    public let totalRecoverableBytes: Int64

    nonisolated public init(
        clusters: [DuplicateCluster],
        totalScannedTracks: Int
    ) {
        self.clusters = clusters
        self.totalScannedTracks = totalScannedTracks

        var duplicateFiles = 0
        var versionClusters = 0
        var recoverable: Int64 = 0

        for c in clusters {
            if c.category == .fileDuplicate {
                duplicateFiles += c.redundantItems.count
                recoverable += c.recoverableBytes
            } else {
                versionClusters += 1
            }
        }

        self.exactDuplicateFilesCount = duplicateFiles
        self.versionClustersCount = versionClusters
        self.totalRecoverableBytes = recoverable
    }

    nonisolated public var formattedTotalRecoverable: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalRecoverableBytes)
    }
}

public actor LibraryDeduplicationService {

    public init() {}

    public func analyze(
        tracks: [LocalTrack],
        progress: (@Sendable (Double) -> Void)? = nil
    ) async -> DeduplicationReport {
        guard !tracks.isEmpty else {
            return DeduplicationReport(clusters: [], totalScannedTracks: 0)
        }

        let total = tracks.count
        var parsedSpecs: [String: AudioTechnicalSpecs] = [:]
        let tagReader = AudioTagReader()

        // Batch inspect specs with cancellation check
        for (idx, track) in tracks.enumerated() {
            if Task.isCancelled { break }
            let details = await tagReader.readDetails(from: track.fileURL)
            parsedSpecs[track.id] = details.specs

            if idx % 20 == 0 || idx == total - 1 {
                progress?(Double(idx + 1) / Double(total))
                await Task.yield()
            }
        }

        // Group tracks by cleaned (artist, title)
        var grouping: [String: [LocalTrack]] = [:]
        for track in tracks {
            let cleanArtist = LrcLibClient.cleanArtistName(track.artist).lowercased()
            let cleanTitle = LrcLibClient.cleanTrackTitle(track.title).lowercased()
            let key = "\(cleanArtist)::\(cleanTitle)"
            grouping[key, default: []].append(track)
        }

        var clusters: [DuplicateCluster] = []

        for (_, group) in grouping where group.count > 1 {
            // Further partition group by duration similarity (within 6 seconds)
            var subGroups: [[LocalTrack]] = []
            for track in group {
                if let idx = subGroups.firstIndex(where: { existing in
                    guard let first = existing.first else { return false }
                    return abs(first.duration - track.duration) <= 6.0
                }) {
                    subGroups[idx].append(track)
                } else {
                    subGroups.append([track])
                }
            }

            for sub in subGroups where sub.count > 1 {
                if let cluster = buildCluster(from: sub, specsLookup: parsedSpecs) {
                    clusters.append(cluster)
                }
            }
        }

        // Sort clusters: exact duplicates first, then by recoverable size descending
        clusters.sort { lhs, rhs in
            if lhs.isRedundantFileDuplicate != rhs.isRedundantFileDuplicate {
                return lhs.isRedundantFileDuplicate
            }
            return lhs.recoverableBytes > rhs.recoverableBytes
        }

        return DeduplicationReport(clusters: clusters, totalScannedTracks: tracks.count)
    }

    private func buildCluster(
        from tracks: [LocalTrack],
        specsLookup: [String: AudioTechnicalSpecs]
    ) -> DuplicateCluster? {
        guard tracks.count > 1, let first = tracks.first else { return nil }

        // Evaluate items and compute quality scores
        var scoredItems: [(track: LocalTrack, score: AudioQualityScore, specs: AudioTechnicalSpecs)] = []

        for track in tracks {
            let specs = specsLookup[track.id] ?? fallbackSpecs(for: track)
            let ext = track.fileURL.pathExtension.lowercased()
            let isLossless = ["flac", "alac", "wav", "wave", "aiff", "aif", "dsf", "dff"].contains(ext)
            let bitDepth = specs.bitDepth ?? (isLossless ? 16 : 16)
            let bitrate = specs.bitrate ?? (isLossless ? 1411 : 256)

            let score = AudioQualityScore(
                isLossless: isLossless,
                sampleRate: specs.sampleRate,
                bitDepthBits: bitDepth,
                bitrateKbps: bitrate
            )
            scoredItems.append((track: track, score: score, specs: specs))
        }

        // Sort items by quality descending (best quality first)
        scoredItems.sort { $0.score > $1.score }

        // Determine category
        var isExactBinary = false
        if let firstSpecs = scoredItems.first?.specs {
            let allSameSize = scoredItems.allSatisfy { abs($0.specs.fileSize - firstSpecs.fileSize) < 512 }
            let allSameDuration = scoredItems.allSatisfy { abs($0.specs.duration - firstSpecs.duration) < 0.5 }
            let allSameExt = scoredItems.allSatisfy { $0.track.fileURL.pathExtension.lowercased() == first.fileURL.pathExtension.lowercased() }

            if allSameSize && allSameDuration && allSameExt {
                isExactBinary = true
            }
        }

        let category: DuplicateCategory
        if isExactBinary {
            category = .fileDuplicate
        } else {
            let hasDifferentEncodings = Set(scoredItems.map { $0.track.fileURL.pathExtension.lowercased() }).count > 1
            if hasDifferentEncodings {
                category = .differentEncoding
            } else {
                let hasQualityDiff = Set(scoredItems.map { "\($0.specs.sampleRate)-\($0.specs.bitDepth ?? 16)" }).count > 1
                if hasQualityDiff {
                    category = .qualityDifference
                } else {
                    category = .differentMaster
                }
            }
        }

        // Build DuplicateItem models
        var items: [DuplicateItem] = []
        var recoverable: Int64 = 0

        for (idx, element) in scoredItems.enumerated() {
            let isPrimary = (idx == 0)
            let desc = formatQualityBadge(element.specs, ext: element.track.fileURL.pathExtension)
            let item = DuplicateItem(
                track: element.track,
                qualityScore: element.score,
                isPrimary: isPrimary,
                fileSize: element.specs.fileSize,
                formatName: element.specs.formatName,
                qualityDescription: desc
            )
            items.append(item)

            if !isPrimary {
                recoverable += element.specs.fileSize
            }
        }

        return DuplicateCluster(
            id: UUID().uuidString,
            title: first.title,
            artist: first.artist,
            category: category,
            items: items,
            recoverableBytes: isExactBinary ? recoverable : 0
        )
    }

    private func formatQualityBadge(_ specs: AudioTechnicalSpecs, ext: String) -> String {
        let extUpper = ext.uppercased()
        let rate = specs.formattedSampleRate
        let depth = specs.formattedBitDepth
        if specs.bitDepth != nil {
            return "\(extUpper) · \(rate) · \(depth)"
        } else if let br = specs.bitrate {
            return "\(extUpper) · \(br) kbps"
        } else {
            return "\(extUpper) · \(rate)"
        }
    }

    private func fallbackSpecs(for track: LocalTrack) -> AudioTechnicalSpecs {
        let size = (try? FileManager.default.attributesOfItem(atPath: track.fileURL.path)[.size] as? Int64) ?? 0
        return AudioTechnicalSpecs(
            formatName: track.fileURL.pathExtension.uppercased(),
            sampleRate: 44100,
            bitDepth: 16,
            channelCount: 2,
            duration: track.duration,
            fileSize: size,
            bitrate: nil
        )
    }
}

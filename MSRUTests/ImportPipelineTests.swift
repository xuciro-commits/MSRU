//
//  ImportPipelineTests.swift
//  MSRUTests
//
//  Created for Identity Resolution Engine Phase 5.
//

import Foundation
import Testing
import AppFoundation
@testable import MSRU

@MainActor
struct ImportPipelineTests {

    @Test
    func processEmptyAudioURLsReturnsEmptyReport() async throws {
        let pipeline = ImportPipeline()
        let report = try await pipeline.process(audioURLs: [])

        #expect(report.totalDiscovered == 0)
        #expect(report.autoCommittedCount == 0)
        #expect(report.pendingReviewClusters.isEmpty)
    }

    @Test
    func processClusteredAudioURLsExecutes11Steps() async throws {
        let dummyURL1 = URL(fileURLWithPath: "/music/Jay Chou - 以父之名.mp3")
        let dummyURL2 = URL(fileURLWithPath: "/music/Jay Chou - 晴天.mp3")

        let pipeline = ImportPipeline()
        let report = try await pipeline.process(audioURLs: [dummyURL1, dummyURL2])

        #expect(report.totalDiscovered == 2)
        #expect(!report.aliasSuggestions.isEmpty)
        if let first = report.aliasSuggestions.first {
            #expect(first.canonicalArtistName == "周杰伦")
        }
    }

    @Test
    func reimportWithLocalAcousticMemoryYields100PercentConfidenceAndAuthoritativeMetadata() async throws {
        let testFP = "sha256_mock_fp_repeat_import_\(UUID().uuidString)"
        let mockArtwork = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46] + Array(repeating: UInt8(0), count: 50))

        // 1. Pre-register acoustic memory
        LocalFingerprintRegistry.shared.register(
            fingerprint: testFP,
            duration: 342.0,
            title: "以父之名",
            artist: "周杰伦",
            album: "叶惠美",
            trackNumber: 1,
            releaseMBID: "mbid_rel_jay_01",
            recordingMBID: "mbid_rec_jay_01",
            artworkData: mockArtwork
        )
        defer {
            LocalFingerprintRegistry.shared.remove(fingerprint: testFP)
        }

        // 2. Incoming file has a messy/disorganized filename: "01. Unknown Track.wav"
        let messyURL = URL(fileURLWithPath: "/music/Disorganized/01. Unknown Track.wav")

        struct MockFingerprinter: AudioFingerprinting {
            let fp: AudioFingerprint
            func generateFingerprint(for fileURL: URL) async throws -> AudioFingerprint {
                fp
            }
        }

        let pipeline = ImportPipeline(
            fingerprinter: MockFingerprinter(fp: AudioFingerprint(fingerprint: testFP, duration: 342.0))
        )

        let report = try await pipeline.process(audioURLs: [messyURL])

        // 3. Must be auto-committed / 100% confidence
        #expect(report.totalDiscovered == 1)
        #expect(report.autoCommittedCount == 1)
        #expect(report.pendingReviewClusters.count == 1)

        let clusterResult = report.pendingReviewClusters[0]
        #expect(clusterResult.confidence >= 0.99)
        #expect(clusterResult.tier == .high)

        let match = clusterResult.trackMatches[0]
        #expect(match.score.confidence >= 0.99)
        #expect(match.score.tier == .high)
        #expect(match.candidate?.title == "以父之名")
        #expect(match.candidate?.artist == "周杰伦")
        #expect(match.candidate?.album == "叶惠美")

        // 4. Test accepting matches passes artworkData to LocalTrack
        let store = ImportReviewStore(report: report)
        let acceptedTracks = store.acceptSelectedMatches()
        #expect(acceptedTracks.count == 1)
        #expect(acceptedTracks[0].title == "以父之名")
        #expect(acceptedTracks[0].artist == "周杰伦")
        #expect(acceptedTracks[0].album == "叶惠美")
        #expect(acceptedTracks[0].artworkData == mockArtwork)

        // 5. Test aggregation into AlbumPresentationModel includes artwork
        let presentationModels = LibraryPresentationAggregator.buildAlbums(from: acceptedTracks)
        #expect(presentationModels.count == 1)
        #expect(presentationModels[0].artworkData == mockArtwork)
        #expect(presentationModels[0].title == "叶惠美")
    }

    @Test
    func filesWithEmbeddedOrMemoryMetadataSkipRemoteNetworkLookup() async throws {
        actor CallCounter {
            var lookupRecordingCount = 0
            func increment() { lookupRecordingCount += 1 }
            var count: Int { lookupRecordingCount }
        }
        let counter = CallCounter()

        struct SpyCatalog: ExternalCatalogService {
            let counter: CallCounter
            func lookupRecording(fingerprint: AudioFingerprint) async throws -> [ExternalRecordingMatch] {
                await counter.increment()
                return []
            }
            func lookupRelease(releaseMBID: String) async throws -> ExternalReleaseMatch? { nil }
            func searchReleases(artist: String, album: String) async throws -> [ExternalReleaseMatch] { [] }
            func fetchArtistAliases(artistMBID: String) async throws -> [EntityAlias] { [] }
        }

        let testFP = "fp_skip_test_\(UUID().uuidString)"
        LocalFingerprintRegistry.shared.register(
            fingerprint: testFP,
            duration: 200.0,
            title: "Song With Metadata",
            artist: "Known Artist",
            album: "Known Album"
        )
        defer {
            LocalFingerprintRegistry.shared.remove(fingerprint: testFP)
        }

        struct StaticFingerprinter: AudioFingerprinting {
            let fp: AudioFingerprint
            func generateFingerprint(for fileURL: URL) async throws -> AudioFingerprint { fp }
        }

        let spy = SpyCatalog(counter: counter)
        let pipeline = ImportPipeline(
            fingerprinter: StaticFingerprinter(fp: AudioFingerprint(fingerprint: testFP, duration: 200.0)),
            catalog: spy
        )

        _ = try await pipeline.process(audioURLs: [URL(fileURLWithPath: "/music/test.wav")])

        // Remote lookup must be 0 because local metadata / memory resolved it!
        let calls = await counter.count
        #expect(calls == 0)
    }
}

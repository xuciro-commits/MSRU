//
//  ShadowLibraryMigrationTests.swift
//  MSRUTests
//
//  Unit tests verifying idempotent shadow migration from legacy JSON stores.
//

import Testing
import Foundation
import AppFoundation
@testable import MSRU

@Suite("Shadow Library Migration Tests")
struct ShadowLibraryMigrationTests {

    @Test("Verify shadow migration from synthetic legacy JSON manifest")
    func testShadowMigrationExecution() async throws {
        let db = try AppDatabase.makeEphemeral()
        let migration = ShadowLibraryMigration(db: db)

        // Create temporary directory with mock external_tracks.json
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sampleTracks = [
            LocalTrack(
                fileURL: URL(fileURLWithPath: "/music/track1.flac"),
                title: "Nocturne Op. 9",
                artist: "Chopin",
                album: "Complete Nocturnes",
                duration: 270,
                artworkReference: "art_chopin.jpg",
                trackNumber: 1,
                year: 1832
            ),
            LocalTrack(
                fileURL: URL(fileURLWithPath: "/music/track2.flac"),
                title: "Clair de Lune",
                artist: "Debussy",
                album: "Suite Bergamasque",
                duration: 310,
                artworkReference: "art_debussy.jpg",
                trackNumber: 3,
                year: 1905
            )
        ]

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let manifestData = try encoder.encode(sampleTracks)
        try manifestData.write(to: tempDir.appendingPathComponent("external_tracks.json"))

        // Run shadow migration
        let report = try await migration.runMigrationIfNeeded(baseDirectory: tempDir)
        #expect(report.isSuccess)
        #expect(report.totalAssetsMigrated == 2)
        #expect(report.totalRecordingsCreated == 2)
        #expect(report.totalReleasesCreated == 2)

        // Verify repeatability / idempotency: running again should not duplicate rows
        let reportRepeat = try await migration.runMigrationIfNeeded(baseDirectory: tempDir)
        #expect(reportRepeat.isSuccess)

        let assetRepo = AssetRepository(db: db)
        let count = try await assetRepo.totalCount()
        #expect(count == 2)
    }

    @Test("Verify reconciliation audit and atomic cutover")
    func testReconciliationAuditAndAtomicCutover() async throws {
        let db = try AppDatabase.makeEphemeral()
        let migration = ShadowLibraryMigration(db: db)

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sampleTracks = [
            LocalTrack(
                fileURL: URL(fileURLWithPath: "/music/track1.flac"),
                title: "Nocturne Op. 9",
                artist: "Chopin",
                album: "Complete Nocturnes",
                duration: 270,
                artworkReference: "art_chopin.jpg",
                trackNumber: 1,
                year: 1832
            )
        ]

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let manifestData = try encoder.encode(sampleTracks)
        try manifestData.write(to: tempDir.appendingPathComponent("external_tracks.json"))

        // Run shadow migration
        _ = try await migration.runMigrationIfNeeded(baseDirectory: tempDir)

        // Run reconciliation audit
        let audit = try await migration.runReconciliationAudit(baseDirectory: tempDir)
        #expect(audit.isClean)
        #expect(audit.legacyCount == 1)
        #expect(audit.mismatchedPaths.isEmpty)

        // Run atomic cutover
        try await migration.performAtomicCutover(baseDirectory: tempDir)
        let backupURL = tempDir.appendingPathComponent("external_tracks.json.legacy.backup")
        #expect(FileManager.default.fileExists(atPath: backupURL.path))
    }
}

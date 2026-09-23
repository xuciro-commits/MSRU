//
//  AssetRepository.swift
//  MSRU
//
//  Repository managing physical audio assets and change detection signatures.
//

import Foundation
import AppFoundation
import GRDB

nonisolated public struct PersistedAssetRecord: Sendable {
    public let id: AssetID
    public let sourceID: SourceID
    public let relativePath: String
    public let fileSize: Int64
    public let mtime: Double
    public let sha256: String?
    public let format: String
    public let bitDepth: Int?
    public let sampleRate: Int
    public let channels: Int
    public let bitrateKbps: Int?
    public let duration: Double
    public let recordingID: RecordingID?
    public let createdAt: Date
    public let updatedAt: Date

    nonisolated public init(
        id: AssetID = .generate(),
        sourceID: SourceID,
        relativePath: String,
        fileSize: Int64,
        mtime: Double,
        sha256: String? = nil,
        format: String,
        bitDepth: Int? = nil,
        sampleRate: Int = 44100,
        channels: Int = 2,
        bitrateKbps: Int? = nil,
        duration: Double = 0,
        recordingID: RecordingID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sourceID = sourceID
        self.relativePath = relativePath
        self.fileSize = fileSize
        self.mtime = mtime
        self.sha256 = sha256
        self.format = format
        self.bitDepth = bitDepth
        self.sampleRate = sampleRate
        self.channels = channels
        self.bitrateKbps = bitrateKbps
        self.duration = duration
        self.recordingID = recordingID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

nonisolated public final class AssetRepository: Sendable {
    private let db: AppDatabase

    nonisolated public init(db: AppDatabase = AppDatabase.shared) {
        self.db = db
    }

    /// Batch upserts physical asset records within an explicit write transaction.
    public func batchUpsert(_ assets: [PersistedAssetRecord]) async throws {
        guard !assets.isEmpty else { return }
        try await db.dbWriter.write { db in
            let statement = try db.makeStatement(sql: """
                INSERT INTO assets (
                    id, source_id, relative_path, file_size, mtime, sha256,
                    format, bit_depth, sample_rate, channels, bitrate_kbps,
                    duration, recording_id, created_at, updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(source_id, relative_path) DO UPDATE SET
                    file_size = excluded.file_size,
                    mtime = excluded.mtime,
                    sha256 = excluded.sha256,
                    format = excluded.format,
                    bit_depth = excluded.bit_depth,
                    sample_rate = excluded.sample_rate,
                    channels = excluded.channels,
                    bitrate_kbps = excluded.bitrate_kbps,
                    duration = excluded.duration,
                    recording_id = COALESCE(excluded.recording_id, assets.recording_id),
                    updated_at = excluded.updated_at
            """)

            let fileAssetStmt = try db.makeStatement(sql: """
                INSERT INTO file_assets (asset_id, relative_path, file_size, mtime, physical_signature)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(asset_id) DO UPDATE SET
                    relative_path = excluded.relative_path,
                    file_size = excluded.file_size,
                    mtime = excluded.mtime,
                    physical_signature = excluded.physical_signature
            """)

            for asset in assets {
                try statement.execute(arguments: [
                    asset.id.rawValue,
                    asset.sourceID.rawValue,
                    asset.relativePath,
                    asset.fileSize,
                    asset.mtime,
                    asset.sha256,
                    asset.format,
                    asset.bitDepth,
                    asset.sampleRate,
                    asset.channels,
                    asset.bitrateKbps,
                    asset.duration,
                    asset.recordingID?.rawValue,
                    asset.createdAt,
                    asset.updatedAt
                ])

                try fileAssetStmt.execute(arguments: [
                    asset.id.rawValue,
                    asset.relativePath,
                    asset.fileSize,
                    asset.mtime,
                    asset.sha256
                ])
            }
        }
    }

    /// Change detection signature lookup: checks whether a file has changed on disk.
    /// Fast 0ms indexed lookup avoiding disk metadata reading.
    public func assetSignatures(forSourceID sourceID: SourceID) async throws -> [String: (mtime: Double, size: Int64)] {
        try await db.reader.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT fa.relative_path, fa.mtime, fa.file_size
                FROM assets a
                JOIN file_assets fa ON fa.asset_id = a.id
                WHERE a.source_id = ?
                """,
                arguments: [sourceID.rawValue]
            )
            var signatures: [String: (mtime: Double, size: Int64)] = [:]
            signatures.reserveCapacity(rows.count)
            for row in rows {
                if let relPath: String = row["relative_path"],
                   let mtime: Double = row["mtime"],
                   let size: Int64 = row["file_size"] {
                    signatures[relPath] = (mtime, size)
                }
            }
            return signatures
        }
    }

    public func totalCount() async throws -> Int {
        try await db.reader.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM assets") ?? 0
        }
    }

    public func delete(ids: Set<AssetID>) async throws {
        guard !ids.isEmpty else { return }
        try await db.dbWriter.write { db in
            let placeholders = ids.map { _ in "?" }.joined(separator: ",")
            let args = ids.map { $0.rawValue }
            let statementArgs = StatementArguments(args) ?? StatementArguments()
            try db.execute(sql: "DELETE FROM assets WHERE id IN (\(placeholders))", arguments: statementArgs)
        }
    }

    // MARK: - Stream Assets

    public struct PersistedStreamAssetRecord: Sendable {
        public let assetID: AssetID
        public let providerID: String
        public let remoteItemID: String
        public let streamURL: String?
        public let isHLS: Bool
        public let expiresAt: Date?

        public init(
            assetID: AssetID,
            providerID: String,
            remoteItemID: String,
            streamURL: String? = nil,
            isHLS: Bool = false,
            expiresAt: Date? = nil
        ) {
            self.assetID = assetID
            self.providerID = providerID
            self.remoteItemID = remoteItemID
            self.streamURL = streamURL
            self.isHLS = isHLS
            self.expiresAt = expiresAt
        }
    }

    public func batchUpsertStreamAssets(_ streamAssets: [PersistedStreamAssetRecord]) async throws {
        guard !streamAssets.isEmpty else { return }
        try await db.dbWriter.write { db in
            let stmt = try db.makeStatement(sql: """
                INSERT INTO stream_assets (asset_id, provider_id, remote_item_id, stream_url, is_hls, expires_at)
                VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT(asset_id) DO UPDATE SET
                    provider_id = excluded.provider_id,
                    remote_item_id = excluded.remote_item_id,
                    stream_url = excluded.stream_url,
                    is_hls = excluded.is_hls,
                    expires_at = excluded.expires_at
            """)
            for sa in streamAssets {
                try stmt.execute(arguments: [
                    sa.assetID.rawValue,
                    sa.providerID,
                    sa.remoteItemID,
                    sa.streamURL,
                    sa.isHLS,
                    sa.expiresAt
                ])
            }
        }
    }
}

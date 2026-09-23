import CryptoKit
import Foundation
import GRDB

/// Analysis is deliberately explicit and runs outside import and playback startup.
/// Measurements are derived cache data; the original audio and tags remain untouched.
actor ReplayGainService {
    static let shared = ReplayGainService()

    private let db: AppDatabase

    init(db: AppDatabase = AppDatabase.shared) {
        self.db = db
    }

    func cachedTrack(for url: URL) async throws -> R128Measurement? {
        let signature = try fileSignature(for: url)
        return try await db.reader.read { db in
            guard let row = try Row.fetchOne(db, sql: """
                SELECT file_size, modified_at, integrated_lufs, sample_peak, duration
                FROM asset_loudness WHERE file_path = ?
                """, arguments: [signature.path]),
                (row["file_size"] as Int64?) == signature.size,
                abs((row["modified_at"] as Double? ?? 0) - signature.mtime) < 0.001 else {
                return nil
            }
            return R128Measurement(integratedLUFS: row["integrated_lufs"],
                                   samplePeak: row["sample_peak"], duration: row["duration"])
        }
    }

    func cachedAlbum(for url: URL) async throws -> R128Measurement? {
        guard try await cachedTrack(for: url) != nil else { return nil }
        let cached: (measurement: R128Measurement, signature: String, paths: [String])? = try await db.reader.read { db in
            guard let row = try Row.fetchOne(db, sql: """
                SELECT al.album_key, al.asset_signature, al.integrated_lufs, al.sample_peak, al.duration
                FROM asset_album_loudness aa JOIN album_loudness al ON al.album_key = aa.album_key
                WHERE aa.file_path = ?
                """, arguments: [url.standardizedFileURL.path]),
                let key: String = row["album_key"],
                let signature: String = row["asset_signature"] else { return nil }
            let paths = try String.fetchAll(db, sql: """
                SELECT file_path FROM asset_album_loudness WHERE album_key = ? ORDER BY file_path
                """, arguments: [key])
            return (R128Measurement(integratedLUFS: row["integrated_lufs"],
                                    samplePeak: row["sample_peak"], duration: row["duration"]),
                    signature, paths)
        }
        guard let cached, !cached.paths.isEmpty else { return nil }
        var signatures: [FileSignature] = []
        for path in cached.paths {
            guard let item = try? fileSignature(for: URL(fileURLWithPath: path)) else { return nil }
            signatures.append(item)
        }
        let currentSignature = Self.digest(signatures.map {
            "\($0.path):\($0.size):\($0.mtime)"
        }.joined(separator: "\n"))
        return currentSignature == cached.signature ? cached.measurement : nil
    }

    @discardableResult
    func analyzeTrack(_ url: URL) async throws -> R128Measurement? {
        if let cached = try await cachedTrack(for: url) { return cached }
        let result = try await scan(url)
        if let measurement = result.meter.measurement() {
            try await persist(measurement, signature: result.signature)
            return measurement
        }
        return nil
    }

    @discardableResult
    func analyzeAlbum(_ urls: [URL]) async throws -> R128Measurement? {
        let uniqueURLs = Array(Set(urls.map(\.standardizedFileURL))).sorted { $0.path < $1.path }
        guard !uniqueURLs.isEmpty else { return nil }
        var energies: [Double] = []
        var peak = 0.0
        var duration = 0.0
        var signatures: [FileSignature] = []
        for url in uniqueURLs {
            try Task.checkCancellation()
            let result = try await scan(url)
            guard let trackMeasurement = result.meter.measurement() else { return nil }
            try await persist(trackMeasurement, signature: result.signature)
            energies.append(contentsOf: result.meter.gatingBlockEnergies)
            peak = max(peak, result.meter.peak)
            duration += result.meter.duration
            signatures.append(result.signature)
        }
        guard let albumMeasurement = R128Meter.measure(energies: energies, samplePeak: peak, duration: duration) else {
            return nil
        }
        let key = Self.digest(signatures.map(\.path).joined(separator: "\n"))
        let signature = Self.digest(signatures.map { "\($0.path):\($0.size):\($0.mtime)" }.joined(separator: "\n"))
        let finalSignatures = signatures
        try await db.dbWriter.write { db in
            try db.execute(sql: """
                INSERT INTO album_loudness (album_key, asset_signature, integrated_lufs, sample_peak, duration, analyzed_at)
                VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT(album_key) DO UPDATE SET asset_signature = excluded.asset_signature,
                    integrated_lufs = excluded.integrated_lufs, sample_peak = excluded.sample_peak,
                    duration = excluded.duration, analyzed_at = excluded.analyzed_at
                """, arguments: [key, signature, albumMeasurement.integratedLUFS,
                                   albumMeasurement.samplePeak, albumMeasurement.duration, Date()])
            for item in finalSignatures {
                try db.execute(sql: """
                    INSERT INTO asset_album_loudness (file_path, album_key) VALUES (?, ?)
                    ON CONFLICT(file_path) DO UPDATE SET album_key = excluded.album_key
                    """, arguments: [item.path, key])
            }
        }
        return albumMeasurement
    }

    private struct FileSignature: Sendable {
        let path: String
        let size: Int64
        let mtime: Double
    }

    private func fileSignature(for url: URL) throws -> FileSignature {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber,
              let modified = attributes[.modificationDate] as? Date else {
            throw CocoaError(.fileReadUnknown)
        }
        return FileSignature(path: url.standardizedFileURL.path,
                             size: size.int64Value, mtime: modified.timeIntervalSince1970)
    }

    private func scan(_ url: URL) async throws -> (meter: R128Meter, signature: FileSignature) {
        let signature = try fileSignature(for: url)
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let decoder: any AudioCodecBackend = ExtendedAudioFormatSupport.supports(url)
            ? FFmpegCodecBackend() : AppleAudioFileDecoder()
        let opened = try await decoder.open(url)
        guard var meter = R128Meter(sampleRate: opened.format.sampleRate,
                                    channels: Int(opened.format.channels)) else {
            await opened.session.close()
            throw ReplayGainError.unsupportedChannels
        }
        do {
            while let block = try await opened.session.read(maxFrames: 8192) {
                try Task.checkCancellation()
                meter.append(block)
            }
            await opened.session.close()
            return (meter, signature)
        } catch {
            await opened.session.close()
            throw error
        }
    }

    private func persist(_ measurement: R128Measurement, signature: FileSignature) async throws {
        try await db.dbWriter.write { db in
            try db.execute(sql: """
                INSERT INTO asset_loudness (file_path, file_size, modified_at, integrated_lufs, sample_peak, duration, analyzed_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(file_path) DO UPDATE SET file_size = excluded.file_size,
                    modified_at = excluded.modified_at, integrated_lufs = excluded.integrated_lufs,
                    sample_peak = excluded.sample_peak, duration = excluded.duration,
                    analyzed_at = excluded.analyzed_at
                """, arguments: [signature.path, signature.size, signature.mtime,
                                   measurement.integratedLUFS, measurement.samplePeak,
                                   measurement.duration, Date()])
        }
    }

    private static func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

private enum ReplayGainError: LocalizedError {
    case unsupportedChannels
    var errorDescription: String? { "Loudness analysis currently supports mono and stereo audio." }
}

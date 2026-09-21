//
//  AppDatabase.swift
//  MSRU
//
//  Source of truth database engine powered by GRDB and SQLite in WAL mode.
//

import Foundation
import AppFoundation

nonisolated public final class AppDatabase: Sendable {

    /// Shared application database instance.
    nonisolated public static let shared: AppDatabase = {
        do {
            let fileManager = FileManager.default
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            let directory = appSupport.appendingPathComponent("MSRU", isDirectory: true)
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let dbURL = directory.appendingPathComponent("library.sqlite")
            return try AppDatabase(at: dbURL)
        } catch {
            fatalError("Failed to initialize AppDatabase: \(error)")
        }
    }()

    /// The underlying database writer (DatabasePool for concurrency with WAL mode).
    public let dbWriter: any DatabaseWriter

    /// In-memory ephemeral database factory for testing and SwiftUI Previews.
    nonisolated public static func makeEphemeral() throws -> AppDatabase {
        var config = Configuration()
        config.foreignKeysEnabled = true
        config.qos = .userInitiated
        let dbQueue = try DatabaseQueue(configuration: config)
        let appDb = AppDatabase(dbWriter: dbQueue)
        try appDb.migrator.migrate(dbQueue)
        return appDb
    }

    /// Primary disk-backed initializer using DatabasePool with WAL mode.
    nonisolated public init(at url: URL) throws {
        var config = Configuration()
        config.foreignKeysEnabled = true
        config.qos = .userInitiated
        config.busyMode = .timeout(5.0)

        // SQLite WAL mode setup for optimal concurrent reads and writes
        let pool = try DatabasePool(path: url.path, configuration: config)
        self.dbWriter = pool
        try migrator.migrate(pool)
    }

    /// Internal initializer for dependency injection and testing.
    nonisolated public init(dbWriter: any DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    /// Migration runner ensuring deterministic schema versioning.
    nonisolated public var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        #if DEBUG
        // Speed up migrations in development/test
        migrator.eraseDatabaseOnSchemaChange = false
        #endif

        Schema_v1.register(to: &migrator)
        Schema_v2.register(to: &migrator)
        return migrator
    }

    /// Direct read access for queries.
    nonisolated public var reader: any DatabaseReader {
        dbWriter
    }
}

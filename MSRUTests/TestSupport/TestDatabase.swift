//
//  TestDatabase.swift
//  MSRUTests
//
//  Lightweight in-memory test database factory for isolated persistence tests.
//

import Foundation
import AppFoundation
import MusicDomain
import GRDB
@testable import MSRU

enum TestDatabase {
    /// Creates a fresh, fully-migrated in-memory SQLite database instance with foreign keys enabled.
    static func makeEphemeral() throws -> AppDatabase {
        try AppDatabase.makeEphemeral()
    }

    /// Seeds a minimal standard source and returns its ID.
    @discardableResult
    static func seedSource(
        in db: AppDatabase,
        id: SourceID = SourceID("src_test_default"),
        name: String = "Test Music Folder",
        uri: String = "/tmp/msru_test"
    ) async throws -> SourceID {
        let repo = SourceRepository(db: db)
        let source = Source(
            id: id,
            sourceType: .localFolder,
            uri: uri,
            displayName: name,
            capabilities: .localFolderDefault,
            isEnabled: true
        )
        try await repo.insertOrUpdate(source)
        return id
    }
}

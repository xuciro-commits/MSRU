//
//  AppDatabaseMigrations.swift
//  MSRU
//
//  Canonical SQLite database migrations using GRDB schema DSL and explicit SQL statements.
//  Maintains deterministic schema progression for identity, assets, and multi-lingual FTS5 search.
//

import Foundation
import AppFoundation
import GRDB

nonisolated enum AppDatabaseMigrations {

    nonisolated static func register(to migrator: inout DatabaseMigrator) {
        registerV1(to: &migrator)
        registerV2(to: &migrator)
    }

    // MARK: - Initial Identity & Asset Schema (v1)

    private static func registerV1(to migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v1_create_music_identity_schema") { db in
            // 1. Sources (Storage locations and capabilities)
            try db.create(table: "sources") { t in
                t.column("id", .text).primaryKey()
                t.column("source_type", .text).notNull()
                t.column("uri", .text).notNull()
                t.column("display_name", .text).notNull()
                t.column("capabilities", .integer).notNull()
                t.column("is_enabled", .boolean).notNull().defaults(to: true)
                t.column("last_reconciled_at", .datetime)
                t.column("bookmark_blob", .blob)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
            }

            // 2. Artists (Canonical musical artist entities)
            try db.create(table: "artists") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("sort_name", .text).notNull().indexed()
                t.column("mbid", .text).unique()
                t.column("disambiguation", .text)
                t.column("country", .text)
                t.column("created_at", .datetime).notNull()
            }

            // 3. Works (Abstract compositions)
            try db.create(table: "works") { t in
                t.column("id", .text).primaryKey()
                t.column("title", .text).notNull()
                t.column("sort_title", .text).notNull()
                t.column("mbid", .text).unique()
                t.column("iswc", .text)
                t.column("created_at", .datetime).notNull()
            }

            // 4. Artwork Assets (Content-addressed storage)
            try db.create(table: "artwork_assets") { t in
                t.column("id", .text).primaryKey()
                t.column("sha256", .text).notNull().unique()
                t.column("mime_type", .text).notNull()
                t.column("width", .integer)
                t.column("height", .integer)
                t.column("byte_size", .integer).notNull()
                t.column("storage_relative_path", .text).notNull()
                t.column("created_at", .datetime).notNull()
            }

            // 5. Releases (Product album issues: CDs, Remasters, Vinyls)
            try db.create(table: "releases") { t in
                t.column("id", .text).primaryKey()
                t.column("title", .text).notNull()
                t.column("sort_title", .text).notNull().indexed()
                t.column("mbid", .text).unique()
                t.column("barcode", .text)
                t.column("release_date", .text)
                t.column("release_year", .integer).indexed()
                t.column("country", .text)
                t.column("label", .text)
                t.column("catalog_number", .text)
                t.column("release_group_mbid", .text)
                t.column("artwork_asset_id", .text).references("artwork_assets", onDelete: .setNull)
                t.column("created_at", .datetime).notNull()
            }

            // 6. Recordings (Performance captures)
            try db.create(table: "recordings") { t in
                t.column("id", .text).primaryKey()
                t.column("work_id", .text).references("works", onDelete: .setNull)
                t.column("title", .text).notNull()
                t.column("sort_title", .text).notNull().indexed()
                t.column("mbid", .text).unique()
                t.column("isrc", .text)
                t.column("duration", .double)
                t.column("is_live", .boolean).notNull().defaults(to: false)
                t.column("acoustid", .text).indexed()
                t.column("created_at", .datetime).notNull()
            }

            // 7. Assets (Physical audio files)
            try db.create(table: "assets") { t in
                t.column("id", .text).primaryKey()
                t.column("source_id", .text).notNull().references("sources", onDelete: .cascade)
                t.column("relative_path", .text).notNull()
                t.column("file_size", .integer).notNull()
                t.column("mtime", .double).notNull()
                t.column("sha256", .text)
                t.column("format", .text).notNull()
                t.column("bit_depth", .integer)
                t.column("sample_rate", .integer).notNull()
                t.column("channels", .integer).notNull().defaults(to: 2)
                t.column("bitrate_kbps", .integer)
                t.column("duration", .double).notNull()
                t.column("recording_id", .text).references("recordings", onDelete: .setNull).indexed()
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
                t.uniqueKey(["source_id", "relative_path"])
            }
            try db.create(index: "idx_assets_signature", on: "assets", columns: ["relative_path", "file_size", "mtime"])

            // 8. Release Tracks (CD Track slots)
            try db.create(table: "release_tracks") { t in
                t.column("id", .text).primaryKey()
                t.column("release_id", .text).notNull().references("releases", onDelete: .cascade)
                t.column("medium_position", .integer).notNull().defaults(to: 1)
                t.column("track_position", .integer).notNull()
                t.column("track_number", .text).notNull()
                t.column("title", .text).notNull()
                t.column("sort_title", .text).notNull()
                t.column("duration", .double)
                t.column("recording_id", .text).notNull().references("recordings", onDelete: .cascade).indexed()
                t.column("created_at", .datetime).notNull()
                t.uniqueKey(["release_id", "medium_position", "track_position"])
            }

            // 9. Artist Credits (Relationship between artist and recording/release)
            try db.create(table: "artist_credits") { t in
                t.column("id", .text).primaryKey()
                t.column("artist_id", .text).notNull().references("artists", onDelete: .cascade)
                t.column("entity_type", .text).notNull()
                t.column("entity_id", .text).notNull()
                t.column("join_phrase", .text)
                t.column("position", .integer).notNull().defaults(to: 0)
                t.column("role", .text).notNull().defaults(to: "primary")
            }
            try db.create(index: "idx_artist_credits_entity", on: "artist_credits", columns: ["entity_type", "entity_id"])
            try db.create(index: "idx_artist_credits_artist", on: "artist_credits", columns: ["artist_id", "entity_type"])

            // 10. External Identifiers (MusicBrainz, AcoustID, Apple Music, etc.)
            try db.create(table: "external_identifiers") { t in
                t.column("id", .text).primaryKey()
                t.column("entity_type", .text).notNull()
                t.column("entity_id", .text).notNull()
                t.column("provider", .text).notNull()
                t.column("external_id", .text).notNull()
                t.column("confidence", .double).notNull().defaults(to: 1.0)
                t.column("updated_at", .datetime).notNull()
                t.uniqueKey(["provider", "external_id"])
            }

            // 11. Fingerprints (Acoustic fingerprint store)
            try db.create(table: "fingerprints") { t in
                t.column("id", .text).primaryKey()
                t.column("asset_id", .text).notNull().unique().references("assets", onDelete: .cascade)
                t.column("algorithm", .text).notNull()
                t.column("duration", .double).notNull()
                t.column("fingerprint_raw", .text).notNull()
                t.column("acoustid", .text)
                t.column("created_at", .datetime).notNull()
            }

            // 12. Library Entries (User's library status, favorites, play counts)
            try db.create(table: "library_entries") { t in
                t.column("id", .text).primaryKey()
                t.column("recording_id", .text).notNull().references("recordings", onDelete: .cascade)
                t.column("release_track_id", .text).references("release_tracks", onDelete: .setNull)
                t.column("is_favorite", .boolean).notNull().defaults(to: false).indexed()
                t.column("rating", .integer).notNull().defaults(to: 0)
                t.column("play_count", .integer).notNull().defaults(to: 0)
                t.column("last_played_at", .datetime)
                t.column("date_added", .datetime).notNull().indexed()
            }

            // 13. Metadata Claims (Raw observations from readers)
            try db.create(table: "metadata_claims") { t in
                t.column("id", .text).primaryKey()
                t.column("asset_id", .text).notNull().references("assets", onDelete: .cascade)
                t.column("field", .text).notNull()
                t.column("raw_value", .text).notNull()
                t.column("source_reader", .text).notNull()
                t.column("confidence", .double).notNull()
                t.column("observed_at", .datetime).notNull()
            }
            try db.create(index: "idx_claims_asset", on: "metadata_claims", columns: ["asset_id", "field"])

            // 14. User Metadata Overrides (Highest priority manual edits)
            try db.create(table: "user_metadata_overrides") { t in
                t.column("id", .text).primaryKey()
                t.column("entity_type", .text).notNull()
                t.column("entity_id", .text).notNull()
                t.column("field", .text).notNull()
                t.column("override_value", .text).notNull()
                t.column("updated_at", .datetime).notNull()
                t.uniqueKey(["entity_type", "entity_id", "field"])
            }

            // 15. FTS5 Virtual Table for Instant Search
            try db.execute(sql: """
            CREATE VIRTUAL TABLE library_fts USING fts5(
                recording_id UNINDEXED,
                track_title,
                artist_name,
                release_title,
                catalog_number,
                tokenize='unicode61 remove_diacritics 2'
            );
            """)
        }
    }

    // MARK: - Release Groups, File Assets, and Metadata Resolutions (v2)

    private static func registerV2(to migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v2_release_groups_file_assets_and_metadata_resolutions") { db in
            // 1. Release Groups (Abstract grouping of product release editions)
            try db.create(table: "release_groups") { t in
                t.column("id", .text).primaryKey()
                t.column("title", .text).notNull()
                t.column("sort_title", .text).notNull().indexed()
                t.column("primary_type", .text).notNull().defaults(to: "album")
                t.column("secondary_types", .text)
                t.column("first_release_date", .text)
                t.column("mbid", .text).unique()
                t.column("created_at", .datetime).notNull()
            }

            // 2. Add release_group_id to releases table if not present
            if try !db.columns(in: "releases").contains(where: { $0.name == "release_group_id" }) {
                try db.alter(table: "releases") { t in
                    t.add(column: "release_group_id", .text).references("release_groups", onDelete: .setNull)
                }
            }

            // 3. File Assets (Detailed physical file attributes decoupled from generic Asset)
            try db.create(table: "file_assets") { t in
                t.column("asset_id", .text).primaryKey().references("assets", onDelete: .cascade)
                t.column("relative_path", .text).notNull()
                t.column("file_size", .integer).notNull()
                t.column("mtime", .double).notNull()
                t.column("physical_signature", .text)
                t.column("inode", .integer)
            }
            try db.create(index: "idx_file_assets_path", on: "file_assets", columns: ["relative_path", "file_size", "mtime"])

            // Backfill file_assets from existing assets if any exist
            try db.execute(sql: """
                INSERT OR IGNORE INTO file_assets (asset_id, relative_path, file_size, mtime, physical_signature)
                SELECT id, relative_path, file_size, mtime, sha256 FROM assets
                WHERE relative_path IS NOT NULL AND file_size IS NOT NULL
            """)

            // 4. Stream Assets (For streaming / remote / provider media)
            try db.create(table: "stream_assets") { t in
                t.column("asset_id", .text).primaryKey().references("assets", onDelete: .cascade)
                t.column("provider_id", .text).notNull()
                t.column("remote_item_id", .text).notNull()
                t.column("stream_url", .text)
                t.column("is_hls", .boolean).notNull().defaults(to: false)
                t.column("expires_at", .datetime)
            }
            try db.create(index: "idx_stream_assets_provider", on: "stream_assets", columns: ["provider_id", "remote_item_id"])

            // 5. Entity Redirects (For stable provisional-to-canonical ID tracking and merges)
            try db.create(table: "entity_redirects") { t in
                t.column("source_id", .text).primaryKey()
                t.column("canonical_id", .text).notNull()
                t.column("entity_type", .text).notNull()
                t.column("reason", .text).notNull().defaults(to: "merge")
                t.column("created_at", .datetime).notNull()
            }
            try db.create(index: "idx_entity_redirects_canonical", on: "entity_redirects", columns: ["canonical_id"])

            // 6. Metadata Resolutions (Consolidated truth value with provenance and confidence score)
            try db.create(table: "metadata_resolutions") { t in
                t.column("id", .text).primaryKey()
                t.column("entity_type", .text).notNull()
                t.column("entity_id", .text).notNull()
                t.column("field_name", .text).notNull()
                t.column("resolved_value", .text).notNull()
                t.column("winning_claim_id", .text).references("metadata_claims", onDelete: .setNull)
                t.column("source_name", .text).notNull()
                t.column("confidence", .double).notNull().defaults(to: 1.0)
                t.column("resolved_at", .datetime).notNull()
            }
            try db.create(index: "idx_resolutions_entity", on: "metadata_resolutions", columns: ["entity_type", "entity_id", "field_name"], unique: true)

            // 7. Add search token columns to library_fts
            try db.execute(sql: """
                DROP TABLE IF EXISTS library_fts;
                CREATE VIRTUAL TABLE library_fts USING fts5(
                    recording_id UNINDEXED,
                    track_title,
                    artist_name,
                    release_title,
                    catalog_number,
                    search_tokens,
                    tokenize = 'unicode61 remove_diacritics 2'
                );
            """)
        }
    }
}

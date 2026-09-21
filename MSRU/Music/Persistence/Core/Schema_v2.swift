//
//  Schema_v2.swift
//  MSRU
//
//  SQLite Schema v2 Migration:
//  - Formal ReleaseGroup modeling (ReleaseGroup -> Release -> ReleaseTrack -> Recording)
//  - Decoupled generic Asset from FileAsset details (Asset != FileAsset)
//  - StreamAsset table for future streaming/remote provider items
//  - Entity Redirects for provisional identity merges and resolution updates
//  - Metadata Resolutions for explainable provenance (chosen value, claim evidence, confidence)
//  - Chinese and multi-lingual search tokens in FTS5
//

import Foundation
import AppFoundation

nonisolated public enum Schema_v2 {

    nonisolated public static func register(to migrator: inout DatabaseMigrator) {
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
                t.column("stream_url", .text).notNull()
                t.column("provider_item_id", .text)
                t.column("drm_type", .text)
            }

            // 5. Add asset_type column to assets if not present
            if try !db.columns(in: "assets").contains(where: { $0.name == "asset_type" }) {
                try db.alter(table: "assets") { t in
                    t.add(column: "asset_type", .text).notNull().defaults(to: "file")
                }
            }

            // 6. Entity Redirects (Handles Provisional Identity Merges, Splits, and Redirects)
            try db.create(table: "entity_redirects") { t in
                t.column("id", .text).primaryKey()
                t.column("source_id", .text).notNull()
                t.column("target_id", .text).notNull()
                t.column("entity_type", .text).notNull()
                t.column("redirect_reason", .text).notNull()
                t.column("created_at", .datetime).notNull()
                t.uniqueKey(["source_id", "entity_type"])
            }
            try db.create(index: "idx_entity_redirects_target", on: "entity_redirects", columns: ["target_id", "entity_type"])

            // 7. Metadata Resolutions (Answers: Why does MSRU believe this canonical value is correct?)
            try db.create(table: "metadata_resolutions") { t in
                t.column("id", .text).primaryKey()
                t.column("recording_id", .text).notNull().references("recordings", onDelete: .cascade)
                t.column("field", .text).notNull()
                t.column("chosen_value", .text).notNull()
                t.column("chosen_claim_id", .text).references("metadata_claims", onDelete: .setNull)
                t.column("confidence", .double).notNull()
                t.column("resolver_version", .text).notNull()
                t.column("reason", .text).notNull()
                t.column("resolved_at", .datetime).notNull()
                t.uniqueKey(["recording_id", "field"])
            }

            // High-Performance Join and Aggregation Indexes (eliminating O(N^2) table scans)
            try db.create(index: "idx_artist_credits_artist", on: "artist_credits", columns: ["artist_id"], ifNotExists: true)
            try db.create(index: "idx_release_tracks_release", on: "release_tracks", columns: ["release_id"], ifNotExists: true)
            try db.create(index: "idx_releases_rg", on: "releases", columns: ["release_group_id"], ifNotExists: true)

            // 8. Rebuild FTS5 table with search_tokens for Chinese & multi-language search
            try db.execute(sql: "DROP TABLE IF EXISTS library_fts")
            try db.execute(sql: """
                CREATE VIRTUAL TABLE library_fts USING fts5(
                    recording_id UNINDEXED,
                    track_title,
                    artist_name,
                    release_title,
                    catalog_number,
                    search_tokens,
                    tokenize='unicode61 remove_diacritics 2'
                );
            """)

            // 9. Re-populate FTS from recordings, artists, and releases
            try db.execute(sql: """
                INSERT INTO library_fts(recording_id, track_title, artist_name, release_title, catalog_number, search_tokens)
                SELECT r.id, r.title, COALESCE(a.name, ''), COALESCE(rel.title, ''), COALESCE(rel.catalog_number, ''),
                       COALESCE(r.title, '') || ' ' || COALESCE(a.name, '') || ' ' || COALESCE(rel.title, '')
                FROM recordings r
                LEFT JOIN artist_credits ac ON ac.entity_id = r.id AND ac.entity_type = 'recording'
                LEFT JOIN artists a ON a.id = ac.artist_id
                LEFT JOIN release_tracks rt ON rt.recording_id = r.id
                LEFT JOIN releases rel ON rel.id = rt.release_id
            """)
        }
    }
}

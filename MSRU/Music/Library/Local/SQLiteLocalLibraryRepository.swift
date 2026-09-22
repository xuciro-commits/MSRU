//
//  SQLiteLocalLibraryRepository.swift
//  MSRU
//
//  Canonical SQLite-backed local library repository replacing legacy JSON manifests.
//  Directly queries and mutates GRDB AppDatabase for sub-millisecond execution.
//

import Foundation
import AVFoundation
import AppFoundation
import GRDB

actor SQLiteLocalLibraryRepository: LocalLibraryRepository {
    private let db: AppDatabase
    private let directory: URL?

    init(db: AppDatabase = AppDatabase.shared, directory: URL? = nil) {
        self.db = db
        self.directory = directory
    }

    // MARK: - Load

    func loadTracks() async throws -> [LocalTrack] {
        // One-time automatic migration of legacy external_tracks.json if present
        await migrateLegacyManifestIfPresent()

        let baseMediaDir = try? self.mediaDirectory()

        return try await db.reader.read { db in
            let sql = """
            SELECT
                a.id as asset_id,
                a.relative_path,
                fa.bookmark_blob,
                rec.id as recording_id,
                rec.title as track_title,
                rec.duration,
                art.name as artist_name,
                rel.title as album_title,
                rel.release_year,
                rel.artwork_asset_id,
                rt.track_number
            FROM assets a
            LEFT JOIN file_assets fa ON fa.asset_id = a.id
            LEFT JOIN recordings rec ON rec.id = a.recording_id
            LEFT JOIN release_tracks rt ON rt.recording_id = rec.id
            LEFT JOIN releases rel ON rel.id = rt.release_id
            LEFT JOIN artist_credits ac ON ac.entity_id = rec.id AND ac.entity_type = 'recording'
            LEFT JOIN artists art ON art.id = ac.artist_id
            ORDER BY rec.sort_title ASC, a.relative_path ASC
            """

            let rows = try Row.fetchAll(db, sql: sql)
            var tracks: [LocalTrack] = []
            var seenPaths = Set<String>()

            for row in rows {
                guard let relativePath: String = row["relative_path"] else { continue }
                if !seenPaths.insert(relativePath).inserted {
                    continue
                }

                let fileURL: URL
                if relativePath.hasPrefix("/") {
                    fileURL = URL(fileURLWithPath: relativePath)
                } else if let base = baseMediaDir {
                    fileURL = base.appendingPathComponent(relativePath)
                } else {
                    fileURL = URL(fileURLWithPath: relativePath)
                }

                let title: String = row["track_title"] ?? fileURL.deletingPathExtension().lastPathComponent
                let artist: String = row["artist_name"] ?? "Unknown Artist"
                let album: String? = row["album_title"]
                let duration: Double = row["duration"] ?? 0
                let artworkRef: String? = row["artwork_asset_id"]
                let year: Int? = row["release_year"]

                var trackNumber: Int? = nil
                if let rawTrk: String = row["track_number"] {
                    let digits = rawTrk.prefix(while: { $0.isNumber })
                    if let num = Int(digits) {
                        trackNumber = num
                    }
                }

                tracks.append(LocalTrack(
                    fileURL: fileURL,
                    title: title,
                    artist: artist,
                    album: album,
                    duration: duration,
                    artworkReference: artworkRef,
                    artworkData: nil,
                    trackNumber: trackNumber,
                    year: year
                ))
            }

            return tracks
        }
    }

    // MARK: - Save In Place

    func saveTracksInPlace(_ tracks: [LocalTrack]) async throws {
        guard !tracks.isEmpty else { return }

        let sourceRepo = SourceRepository(db: db)
        let identityRepo = IdentityRepository(db: db)
        let assetRepo = AssetRepository(db: db)
        let sourceID = SourceID("src_local_default")

        let defaultSource = Source(
            id: sourceID,
            sourceType: .localFolder,
            uri: "local://default",
            displayName: "Local Media Library",
            capabilities: .localFolderDefault,
            isEnabled: true
        )
        try? await sourceRepo.insertOrUpdate(defaultSource)

        // Group tracks by album title to derive stable primary albumArtist (prevent duet fragmentation)
        var tracksByAlbum: [String: [LocalTrack]] = [:]
        for t in tracks {
            let alb = (t.album?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                ? t.album!.trimmingCharacters(in: .whitespacesAndNewlines)
                : "Unknown Album"
            tracksByAlbum[alb, default: []].append(t)
        }

        var primaryArtistByAlbum: [String: String] = [:]
        for (alb, tList) in tracksByAlbum {
            let counts = tList.reduce(into: [String: Int]()) { $0[$1.artist, default: 0] += 1 }
            let cand = counts.max(by: { $0.value < $1.value })?.key ?? tList.first?.artist ?? "Unknown Artist"
            let primary = cand.components(separatedBy: CharacterSet(charactersIn: ",/&")).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? cand
            primaryArtistByAlbum[alb] = primary.isEmpty ? cand : primary
        }

        var artists: [(id: ArtistID, name: String)] = []
        var recordings: [(id: RecordingID, title: String, duration: Double?)] = []
        var releaseGroups: [(id: ReleaseGroupID, title: String)] = []
        var releases: [(id: ReleaseID, releaseGroupID: ReleaseGroupID?, title: String, year: Int?, artworkAssetID: String?)] = []
        var releaseTracks: [(id: ReleaseTrackID, releaseID: ReleaseID, trackNumber: Int, title: String, duration: Double?, recordingID: RecordingID)] = []
        var artistCredits: [(artistID: ArtistID, entityType: String, entityID: String)] = []
        var assets: [PersistedAssetRecord] = []
        var bookmarksToSave: [(assetID: String, bookmarkData: Data)] = []

        let bookmarkOptions = SecurityScopePolicy.bookmarkCreationOptions

        for track in tracks {
            let relTitle = (track.album?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                ? track.album!.trimmingCharacters(in: .whitespacesAndNewlines)
                : "Unknown Album"
            let albumArtist = primaryArtistByAlbum[relTitle] ?? track.artist
            let recID = DeterministicID.recording(title: track.title, artist: track.artist)
            let albumArtID = DeterministicID.artist(name: albumArtist)
            let trackArtID = DeterministicID.artist(name: track.artist)
            let rgID = DeterministicID.releaseGroup(artist: albumArtist, title: relTitle)
            let relID = DeterministicID.release(artist: albumArtist, title: relTitle)
            let trkID = DeterministicID.releaseTrack(releaseID: relID, medium: 1, track: track.trackNumber ?? 1)
            let relativePath = track.fileURL.standardizedFileURL.path
            let astID = DeterministicID.asset(sourceID: sourceID, relativePath: relativePath)

            artists.append((id: trackArtID, name: track.artist))
            if trackArtID != albumArtID {
                artists.append((id: albumArtID, name: albumArtist))
            }

            recordings.append((id: recID, title: track.title, duration: track.duration))
            releaseGroups.append((id: rgID, title: relTitle))

            var artRef = track.artworkReference
            if artRef == nil, let artData = track.artworkData {
                artRef = LocalArtworkStorage.shared.storeArtwork(artData)
            }
            releases.append((id: relID, releaseGroupID: rgID, title: relTitle, year: track.year, artworkAssetID: artRef))
            releaseTracks.append((id: trkID, releaseID: relID, trackNumber: track.trackNumber ?? 1, title: track.title, duration: track.duration, recordingID: recID))
            artistCredits.append((artistID: trackArtID, entityType: "recording", entityID: recID.rawValue))
            artistCredits.append((artistID: albumArtID, entityType: "release", entityID: relID.rawValue))

            assets.append(PersistedAssetRecord(
                id: astID,
                sourceID: sourceID,
                relativePath: relativePath,
                fileSize: 0,
                mtime: Date().timeIntervalSince1970,
                format: track.fileURL.pathExtension.uppercased(),
                duration: track.duration,
                recordingID: recID
            ))

            if let bookmark = try? track.fileURL.bookmarkData(options: bookmarkOptions, includingResourceValuesForKeys: nil, relativeTo: nil) {
                bookmarksToSave.append((assetID: astID.rawValue, bookmarkData: bookmark))
            }
        }

        try await identityRepo.batchUpsertEntities(
            artists: artists,
            recordings: recordings,
            releaseGroups: releaseGroups,
            releases: releases,
            releaseTracks: releaseTracks,
            artistCredits: artistCredits
        )
        try await assetRepo.batchUpsert(assets)

        // Save bookmarks to file_assets
        if !bookmarksToSave.isEmpty {
            let finalBookmarks = bookmarksToSave
            try await db.dbWriter.write { db in
                for item in finalBookmarks {
                    try db.execute(
                        sql: "UPDATE file_assets SET bookmark_blob = ? WHERE asset_id = ?",
                        arguments: [item.bookmarkData, item.assetID]
                    )
                }
            }
        }
    }

    func saveTrackInPlace(_ track: LocalTrack) async throws {
        try await saveTracksInPlace([track])
    }

    func batchUpsertTracks(_ tracks: [LocalTrack]) async throws {
        try await saveTracksInPlace(tracks)
    }

    // MARK: - Import

    func importTrack(from url: URL) async throws -> LocalTrack? {
        let list = try await importTracks(from: [url])
        return list.first
    }

    func importTracks(from urls: [URL]) async throws -> [LocalTrack] {
        let supported = urls.filter { LocalAudioFormatSupport.supports($0) }
        guard !supported.isEmpty else { return [] }

        var readList: [LocalTrack] = []
        for url in supported {
            let hasSecurityAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasSecurityAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            do {
                let track = try await readTrack(from: url)
                readList.append(track)
            } catch {
                print("Batch read failed:", url.lastPathComponent, error.localizedDescription)
            }
        }

        try await saveTracksInPlace(readList)
        return readList
    }

    // MARK: - Delete

    func deleteTracks(withIDs ids: Set<String>, deletePhysicalFiles: Bool) async throws {
        guard !ids.isEmpty else { return }

        // Find matching paths and file URLs
        let (matchedPaths, matchedUrls) = try await db.reader.read { db -> (Set<String>, [URL]) in
            var paths: Set<String> = []
            var urls: [URL] = []
            let rows = try Row.fetchAll(db, sql: "SELECT relative_path FROM assets")
            for row in rows {
                guard let path: String = row["relative_path"] else { continue }
                let url = URL(fileURLWithPath: path)
                if ids.contains(path) || ids.contains(url.standardizedFileURL.path) || ids.contains(url.absoluteString) {
                    paths.insert(path)
                    urls.append(url)
                }
            }
            return (paths, urls)
        }

        var pathsToDelete = matchedPaths
        var urlsToTrash = matchedUrls

        if pathsToDelete.isEmpty {
            for id in ids {
                if id.hasPrefix("/") || id.contains("/") {
                    pathsToDelete.insert(id)
                    urlsToTrash.append(URL(fileURLWithPath: id))
                }
            }
        }

        guard !pathsToDelete.isEmpty else { return }

        let identityRepo = IdentityRepository(db: db)
        _ = try await identityRepo.deleteTracks(relativePaths: pathsToDelete)

        if deletePhysicalFiles {
            var foldersToCheck: Set<URL> = []
            for fileURL in urlsToTrash {
                let hasAccess = fileURL.startAccessingSecurityScopedResource()
                defer { if hasAccess { fileURL.stopAccessingSecurityScopedResource() } }

                let parent = fileURL.deletingLastPathComponent()
                foldersToCheck.insert(parent)

                do {
                    try FileManager.default.trashItem(at: fileURL, resultingItemURL: nil)
                } catch {
                    try? FileManager.default.removeItem(at: fileURL)
                }
            }

            // Cascade clean orphan companion covers and empty folders if no audio files remain
            for folder in foldersToCheck {
                let items = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
                let audioItems = items.filter { LocalAudioFormatSupport.supports($0) }
                if audioItems.isEmpty {
                    let companionImages = items.filter { item in
                        let ext = item.pathExtension.lowercased()
                        return ["jpg", "jpeg", "png", "webp"].contains(ext)
                    }
                    for img in companionImages {
                        do {
                            try FileManager.default.trashItem(at: img, resultingItemURL: nil)
                        } catch {
                            try? FileManager.default.removeItem(at: img)
                        }
                    }

                    let remaining = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [])) ?? []
                    let nonHiddenRemaining = remaining.filter { !$0.lastPathComponent.hasPrefix(".") }
                    if nonHiddenRemaining.isEmpty {
                        do {
                            try FileManager.default.trashItem(at: folder, resultingItemURL: nil)
                        } catch {
                            try? FileManager.default.removeItem(at: folder)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Legacy Migration

    private func migrateLegacyManifestIfPresent() async {
        guard let manifestURL = try? externalManifestURL(),
              FileManager.default.fileExists(atPath: manifestURL.path),
              let data = try? Data(contentsOf: manifestURL) else {
            return
        }

        struct LegacyRecord: Codable {
            let fileURL: URL
            let title: String
            let artist: String
            let album: String?
            let duration: TimeInterval
            let artworkRelativePath: String?
            let trackNumber: Int?
            let year: Int?
        }

        if let records = try? JSONDecoder().decode([LegacyRecord].self, from: data), !records.isEmpty {
            let tracks = records.map { rec in
                LocalTrack(
                    fileURL: rec.fileURL,
                    title: rec.title,
                    artist: rec.artist,
                    album: rec.album,
                    duration: rec.duration,
                    artworkReference: rec.artworkRelativePath,
                    artworkData: nil,
                    trackNumber: rec.trackNumber,
                    year: rec.year
                )
            }
            try? await saveTracksInPlace(tracks)
        }

        // Delete legacy manifest file after one-time migration
        try? FileManager.default.removeItem(at: manifestURL)
    }

    private func externalManifestURL() throws -> URL {
        try mediaDirectory().appendingPathComponent("external_tracks.json")
    }

    // MARK: - Metadata Extraction

    func readTrack(from url: URL) async throws -> LocalTrack {
        try await Self.readTrack(from: url)
    }

    static func readTrack(from url: URL) async throws -> LocalTrack {
        let url = url.resolvingSymlinksInPath().standardizedFileURL
        let asset = AVURLAsset(url: url)

        // Fast path for DSD DSF files: bypass AVFoundation to prevent CoreAudio FFR errors
        if url.pathExtension.lowercased() == "dsf", let dsfMeta = DSFHeaderReader.readMetadata(from: url) {
            let parsed = FileNameHeuristicParser.parse(fileURL: url)
            let rule = PathHeuristicRuleStore.shared.match(fileURL: url)
            let title = dsfMeta.title ?? parsed.title
            let artist = dsfMeta.artist ?? rule?.targetArtist ?? parsed.artist ?? "Unknown Artist"
            var album = dsfMeta.album ?? rule?.targetAlbum ?? parsed.album
            if let alb = album, FileNameHeuristicParser.isGenericFolderName(alb) {
                album = nil
            }
            let artworkData = dsfMeta.artworkData ?? LocalArtworkExtractor.extractFromDirectory(folderURL: url.deletingLastPathComponent())
            let trackNumber = dsfMeta.trackNumber ?? parsed.trackNumber
            let year = dsfMeta.year ?? parsed.year

            return LocalTrack(
                fileURL: url,
                title: title,
                artist: artist,
                album: album,
                duration: dsfMeta.duration,
                artworkData: artworkData,
                trackNumber: trackNumber,
                year: year
            )
        }

        var metadata: [AVMetadataItem] = []
        if let common = try? await asset.load(.commonMetadata) {
            metadata.append(contentsOf: common)
        }
        if let all = try? await asset.load(.metadata) {
            metadata.append(contentsOf: all)
        }
        if let formats = try? await asset.load(.availableMetadataFormats) {
            for fmt in formats {
                if let items = try? await asset.loadMetadata(for: fmt) {
                    metadata.append(contentsOf: items)
                }
            }
        }

        // Title
        let parsed = FileNameHeuristicParser.parse(fileURL: url)
        let rule = PathHeuristicRuleStore.shared.match(fileURL: url)

        let rawTitle = await metadataString(
            identifier: .commonIdentifierTitle,
            alternateKeys: ["title"],
            metadata: metadata
        )
        let title = (rawTitle != nil && !rawTitle!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            ? rawTitle!
            : parsed.title

        // Artist
        let rawArtist = await metadataString(
            identifier: .commonIdentifierArtist,
            alternateKeys: ["artist", "albumartist", "composer"],
            metadata: metadata
        )
        let artist: String
        if let rawArtist, !rawArtist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, rawArtist != "Unknown Artist" {
            artist = rawArtist
        } else {
            artist = rule?.targetArtist ?? parsed.artist ?? "Unknown Artist"
        }

        // Clean redundant artist prefix from title if present (e.g. "李克勤-一生不变" -> "一生不变")
        var finalTitle = title
        if finalTitle.lowercased().hasPrefix(artist.lowercased()) {
            let stripped = finalTitle.dropFirst(artist.count).trimmingCharacters(in: CharacterSet(charactersIn: " -–—_"))
            if !stripped.isEmpty {
                finalTitle = stripped
            }
        }

        // Album
        let rawAlbum = await metadataString(
            identifier: .commonIdentifierAlbumName,
            alternateKeys: ["album"],
            metadata: metadata
        )
        var finalAlbum = (rawAlbum != nil && !rawAlbum!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            ? rawAlbum
            : (rule?.targetAlbum ?? parsed.album)

        // Safety gate: never allow album == artist or generic folder name
        if let alb = finalAlbum {
            let trimmed = alb.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.lowercased() == artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() || FileNameHeuristicParser.isGenericFolderName(trimmed) {
                finalAlbum = nil
            }
        }

        // Artwork
        var artworkData = await metadataData(
            identifier: .commonIdentifierArtwork,
            metadata: metadata
        )
        if artworkData == nil {
            artworkData = LocalArtworkExtractor.extractFromDirectory(folderURL: url.deletingLastPathComponent())
        }

        // TrackNumber & Year
        var trackNumber: Int? = parsed.trackNumber
        if let rawTrk = await metadataString(identifier: .id3MetadataTrackNumber, alternateKeys: ["tracknumber", "trck"], metadata: metadata) {
            let digits = rawTrk.prefix(while: { $0.isNumber })
            if let num = Int(digits) {
                trackNumber = num
            }
        }

        var year: Int? = parsed.year
        if let rawDate = await metadataString(identifier: .id3MetadataYear, alternateKeys: ["date", "year", "tyer", "tdrc"], metadata: metadata) {
            let digits = rawDate.prefix(while: { $0.isNumber })
            if digits.count >= 4, let yr = Int(digits.prefix(4)) {
                year = yr
            }
        }

        // Duration
        let duration: TimeInterval
        do {
            let durationValue = try await asset.load(.duration)
            let seconds = durationValue.seconds
            duration = seconds.isFinite && seconds > 0 ? seconds : 0
        } catch {
            duration = 0
        }

        return LocalTrack(
            fileURL: url,
            title: finalTitle,
            artist: artist,
            album: finalAlbum,
            duration: duration,
            artworkData: artworkData,
            trackNumber: trackNumber,
            year: year
        )
    }

    private static func metadataString(
        identifier: AVMetadataIdentifier,
        alternateKeys: [String] = [],
        metadata: [AVMetadataItem]
    ) async -> String? {
        let items = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: identifier)
        for item in items {
            if let val = try? await item.load(.stringValue), !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return val.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        let lowerAlts = alternateKeys.map { $0.lowercased() }
        for item in metadata {
            let keyStr = (item.key as? String)?.lowercased() ?? ""
            let idStr = item.identifier?.rawValue.lowercased() ?? ""
            for alt in lowerAlts {
                if keyStr == alt || idStr == alt || idStr.hasSuffix("/" + alt) {
                    if let val = try? await item.load(.stringValue), !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        return val.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
        }
        return nil
    }

    private static func metadataData(
        identifier: AVMetadataIdentifier,
        metadata: [AVMetadataItem]
    ) async -> Data? {
        let items = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: identifier)
        for item in items {
            if let data = try? await item.load(.dataValue), LocalArtworkExtractor.isValidImageData(data) {
                return data
            }
        }

        for item in metadata {
            let idStr = item.identifier?.rawValue.lowercased() ?? ""
            let keyStr = (item.key as? String)?.lowercased() ?? ""
            if idStr.contains("picture") || keyStr.contains("picture") || idStr.contains("artwork") || keyStr.contains("artwork") {
                if let data = try? await item.load(.dataValue), LocalArtworkExtractor.isValidImageData(data) {
                    return data
                }
            }
        }

        for item in metadata {
            if let data = try? await item.load(.dataValue), LocalArtworkExtractor.isValidImageData(data) {
                return data
            }
        }
        return nil
    }

    private func mediaDirectory() throws -> URL {
        if let directory {
            return directory
        }
        guard let support = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "SQLiteLocalLibraryRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not access application support directory."])
        }
        let resolved = support.appendingPathComponent("MSRU/LocalMedia", isDirectory: true)
        try FileManager.default.createDirectory(at: resolved, withIntermediateDirectories: true)
        return resolved
    }
}


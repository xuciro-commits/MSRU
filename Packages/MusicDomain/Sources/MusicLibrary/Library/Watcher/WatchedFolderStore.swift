//
//  WatchedFolderStore.swift
//  MSRU
//
//  Created for Task 31: Watched Folders background monitoring and continuous ingestion.
//

import Foundation
import Observation
import AppFoundation
import GRDB
import MusicDomain

/// Central state store managing watched folders, background file-system events, and automatic continuous ingestion.
@MainActor
@Observable
public final class WatchedFolderStore {

    public static let defaultUserWatchedPath = "/Volumes/资料盘/70-媒体与收藏/71-音乐库/Artists/"

    public private(set) var folders: [WatchedFolder] = []
    public private(set) var isScanning: Bool = false
    public private(set) var lastDiscoveredCount: Int = 0
    public private(set) var statusMessage: String? = nil

    private let localStore: LocalLibraryStore
    private let watcherService: FolderWatcherService
    private let scanner: WatchedFolderScanner
    private let db: AppDatabase
    private var debounceTasks: [UUID: Task<Void, Never>] = [:]
    private var activeScopedFolders: [UUID: URL] = [:]

    public init(
        localStore: LocalLibraryStore,
        watcherService: FolderWatcherService = FolderWatcherService(),
        scanner: WatchedFolderScanner = WatchedFolderScanner(),
        db: AppDatabase = AppDatabase.shared,
        manifestURL: URL? = nil,
        seedDefaultFolder: Bool = true
    ) {
        self.localStore = localStore
        self.watcherService = watcherService
        self.scanner = scanner
        self.db = db
        loadPersistedFolders()
        if seedDefaultFolder {
            checkAndSeedDefaultFolderIfNeeded()
        }
    }

    // MARK: - Lifecycle

    /// Starts monitoring all enabled watched folders.
    public func startMonitoring() {
        for folder in folders where folder.isEnabled {
            if SecurityScopePolicy.isLocalVolume(folder.url) {
                startWatchingFolder(folder)
            }
        }
        // NOTE: On startup, do NOT rescanAll().
        // Persistent library state is already hydrated by LocalLibraryStore.
        // Network folders (NAS/SMB) only refresh via explicit manual user request.
        // Local folders reactively monitor changes via FSEvents.
    }

    /// Stops all background monitoring streams.
    public func stopMonitoring() {
        for task in debounceTasks.values {
            task.cancel()
        }
        debounceTasks.removeAll()
        watcherService.stopAll()
        #if os(macOS)
        for url in activeScopedFolders.values {
            url.stopAccessingSecurityScopedResource()
        }
        activeScopedFolders.removeAll()
        #endif
    }

    // MARK: - Watcher Management

    private func startWatchingFolder(_ folder: WatchedFolder) {
        // Network shares (SMB/NFS) cannot be monitored via FSEvents
        guard SecurityScopePolicy.isLocalVolume(folder.url) else { return }

        let folderID = folder.id
        #if os(macOS)
        if activeScopedFolders[folderID] == nil {
            if let bookmark = folder.bookmarkData,
               let resolved = SecurityScopePolicy.resolveBookmark(bookmark) {
                if SecurityScopePolicy.isSandboxed && resolved.url.startAccessingSecurityScopedResource() {
                    activeScopedFolders[folderID] = resolved.url
                }
            } else if SecurityScopePolicy.isSandboxed && folder.url.startAccessingSecurityScopedResource() {
                activeScopedFolders[folderID] = folder.url
            }
        }
        #endif

        watcherService.startWatching(folder: folder) { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleFolderEvent(folderID: folderID)
            }
        }
    }

    private func handleFolderEvent(folderID: UUID) {
        debounceTasks[folderID]?.cancel()
        debounceTasks[folderID] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000) // 1.2s debounce
            guard !Task.isCancelled else { return }
            await self?.rescanFolder(id: folderID)
        }
    }

    // MARK: - Folder Operations

    public func addFolder(url: URL, autoIngest: Bool = true) async {
        let cleanURL = url.resolvingSymlinksInPath().standardizedFileURL
        if let existing = folders.first(where: { $0.url.standardizedFileURL == cleanURL }) {
            if !existing.isEnabled {
                toggleFolder(id: existing.id)
            }
            return
        }

        let bookmarkOptions = SecurityScopePolicy.bookmarkCreationOptions
        let bookmark = try? cleanURL.bookmarkData(options: bookmarkOptions, includingResourceValuesForKeys: nil, relativeTo: nil)

        let newFolder = WatchedFolder(
            url: cleanURL,
            bookmarkData: bookmark,
            isEnabled: true,
            autoIngest: autoIngest
        )
        folders.append(newFolder)
        persistFolders()

        startWatchingFolder(newFolder)
        await rescanFolder(id: newFolder.id)
    }

    public func removeFolder(id: UUID) {
        debounceTasks[id]?.cancel()
        debounceTasks.removeValue(forKey: id)
        watcherService.stopWatching(id: id)
        #if os(macOS)
        activeScopedFolders[id]?.stopAccessingSecurityScopedResource()
        activeScopedFolders.removeValue(forKey: id)
        #endif
        folders.removeAll { $0.id == id }
        persistFolders()
    }

    public func toggleFolder(id: UUID) {
        guard let index = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[index].isEnabled.toggle()
        let updated = folders[index]
        persistFolders()

        if updated.isEnabled {
            startWatchingFolder(updated)
            Task {
                await rescanFolder(id: id)
            }
        } else {
            debounceTasks[id]?.cancel()
            debounceTasks.removeValue(forKey: id)
            watcherService.stopWatching(id: id)
            #if os(macOS)
            activeScopedFolders[id]?.stopAccessingSecurityScopedResource()
            activeScopedFolders.removeValue(forKey: id)
            #endif
        }
    }

    public func setAutoIngest(id: UUID, autoIngest: Bool) {
        guard let index = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[index].autoIngest = autoIngest
        persistFolders()
    }

    // MARK: - Scanning & Ingestion

    public func rescanAll() async {
        guard !isScanning else { return }
        isScanning = true
        defer { isScanning = false }

        var totalDiscovered = 0
        for folder in folders where folder.isEnabled {
            let discovered = await scanSingleFolder(folder)
            totalDiscovered += discovered
        }
        lastDiscoveredCount = totalDiscovered
        if totalDiscovered > 0 {
            statusMessage = "Discovered and ingested \(totalDiscovered) new tracks."
        }
    }

    public func rescanFolder(id: UUID) async {
        guard let folder = folders.first(where: { $0.id == id && $0.isEnabled }) else { return }
        isScanning = true
        defer { isScanning = false }

        let discovered = await scanSingleFolder(folder)
        lastDiscoveredCount = discovered
        if discovered > 0 {
            statusMessage = "Ingested \(discovered) new tracks from \(folder.displayName)."
        }
    }

    private func scanSingleFolder(_ folder: WatchedFolder) async -> Int {
        let targetURL: URL
        var hasSecurityScope = false

        if let existingScope = activeScopedFolders[folder.id] {
            targetURL = existingScope
        } else if let bookmark = folder.bookmarkData,
                  let resolved = SecurityScopePolicy.resolveBookmark(bookmark) {
            targetURL = resolved.url
            if SecurityScopePolicy.isSandboxed {
                hasSecurityScope = targetURL.startAccessingSecurityScopedResource()
                if hasSecurityScope {
                    activeScopedFolders[folder.id] = targetURL
                }
            }
        } else {
            targetURL = folder.url
            if SecurityScopePolicy.isSandboxed {
                hasSecurityScope = targetURL.startAccessingSecurityScopedResource()
                if hasSecurityScope {
                    activeScopedFolders[folder.id] = targetURL
                }
            }
        }

        guard FileManager.default.fileExists(atPath: targetURL.path) else {
            return 0
        }

        // Ensure localStore is hydrated before diffing
        await localStore.loadIfNeeded()

        let targetPath = targetURL.standardizedFileURL.path
        let tracksInFolder: [LocalTrack]
        do {
            tracksInFolder = try await localStore.fetchTracks(inFolder: targetURL)
        } catch {
            print("Watcher failed to read local tracks in \(targetPath):", error.localizedDescription)
            return 0
        }

        let cache = await LocalFingerprintRegistry.shared.assetCache
        let signatures = await LocalFingerprintRegistry.shared.signatures
        let result = await scanner.reconcileFolder(
            targetURL: targetURL,
            existingTracksInFolder: tracksInFolder,
            assetCache: cache,
            signatures: signatures
        )

        if folder.autoIngest {
            let tracksToIngest = result.newTracks + result.modifiedTracks
            if !tracksToIngest.isEmpty {
                do {
                    try await localStore.addTracks(tracksToIngest)
                } catch {
                    print("Watcher failed to ingest tracks:", error.localizedDescription)
                }
            }

            if !result.deletedTrackPaths.isEmpty {
                await localStore.deleteTracks(withIDs: Set(result.deletedTrackPaths))
            }
        }

        // Update folder stats
        if let idx = folders.firstIndex(where: { $0.id == folder.id }) {
            folders[idx].trackCount = result.totalScannedCount
            folders[idx].lastScannedAt = Date()
            persistFolders()
        }

        return result.discoveredCount
    }

    // MARK: - Persistence

    private func persistFolders() {
        try? db.dbWriter.write { db in
            try db.execute(sql: "DELETE FROM watched_folders")
            for folder in self.folders {
                try db.execute(
                    sql: """
                    INSERT INTO watched_folders (id, url, bookmark_blob, is_active, track_count, last_scanned_at, added_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                    arguments: [
                        folder.id.uuidString,
                        folder.url.standardizedFileURL.path,
                        folder.bookmarkData,
                        folder.isEnabled ? 1 : 0,
                        folder.trackCount,
                        folder.lastScannedAt,
                        Date()
                    ]
                )
            }
        }
    }

    private func loadPersistedFolders() {
        migrateLegacyWatchedFoldersIfPresent()

        let loaded = try? db.reader.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM watched_folders ORDER BY added_at ASC")
            return rows.compactMap { row -> WatchedFolder? in
                guard let idStr: String = row["id"],
                      let id = UUID(uuidString: idStr),
                      let urlStr: String = row["url"] else { return nil }
                let url = URL(fileURLWithPath: urlStr)
                let bookmarkBlob: Data? = row["bookmark_blob"]
                let isActive: Bool = row["is_active"] ?? true
                let trackCount: Int = row["track_count"] ?? 0
                let lastScannedAt: Date? = row["last_scanned_at"]

                return WatchedFolder(
                    id: id,
                    url: url,
                    bookmarkData: bookmarkBlob,
                    isEnabled: isActive,
                    autoIngest: true,
                    lastScannedAt: lastScannedAt,
                    trackCount: trackCount
                )
            }
        }
        if let loaded, !loaded.isEmpty {
            self.folders = loaded
        }
    }

    private func migrateLegacyWatchedFoldersIfPresent() {
        guard let legacyURL = defaultLegacyWatchedFoldersURL(),
              FileManager.default.fileExists(atPath: legacyURL.path),
              let data = try? Data(contentsOf: legacyURL),
              let decoded = try? JSONDecoder().decode([WatchedFolder].self, from: data),
              !decoded.isEmpty else {
            return
        }

        self.folders = decoded
        persistFolders()
        try? FileManager.default.removeItem(at: legacyURL)
    }

    private func defaultLegacyWatchedFoldersURL() -> URL? {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        return support.appendingPathComponent("MSRU/watched_folders.json")
    }

    // MARK: - Default Folder Seeding

    private func checkAndSeedDefaultFolderIfNeeded() {
        let path = Self.defaultUserWatchedPath
        guard FileManager.default.fileExists(atPath: path) else { return }

        let defaultURL = URL(fileURLWithPath: path).standardizedFileURL
        let exists = folders.contains(where: { $0.url.standardizedFileURL.path == defaultURL.path })
        if !exists {
            let bookmarkOptions = SecurityScopePolicy.bookmarkCreationOptions
            let bookmark = try? defaultURL.bookmarkData(options: bookmarkOptions, includingResourceValuesForKeys: nil, relativeTo: nil)

            let defaultFolder = WatchedFolder(
                url: defaultURL,
                bookmarkData: bookmark,
                isEnabled: true,
                autoIngest: true
            )
            folders.insert(defaultFolder, at: 0)
            persistFolders()
        }
    }
}

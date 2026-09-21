//
//  WatchedFolderStore.swift
//  MSRU
//
//  Created for Task 31: Watched Folders background monitoring and continuous ingestion.
//

import Foundation
import Observation
import AppFoundation

/// Central state store managing watched folders, background file-system events, and automatic continuous ingestion.
@MainActor
@Observable
final class WatchedFolderStore {

    static let defaultUserWatchedPath = "/Volumes/资料盘/70-媒体与收藏/71-音乐库/Artists/"

    private(set) var folders: [WatchedFolder] = []
    private(set) var isScanning: Bool = false
    private(set) var lastDiscoveredCount: Int = 0
    private(set) var statusMessage: String? = nil

    private let localStore: LocalLibraryStore
    private let watcherService: FolderWatcherService
    private let scanner: WatchedFolderScanner
    private let manifestURL: URL?
    private var debounceTasks: [UUID: Task<Void, Never>] = [:]
    private var activeScopedFolders: [UUID: URL] = [:]

    public init(
        localStore: LocalLibraryStore,
        watcherService: FolderWatcherService = FolderWatcherService(),
        scanner: WatchedFolderScanner = WatchedFolderScanner(),
        manifestURL: URL? = nil,
        seedDefaultFolder: Bool = true
    ) {
        self.localStore = localStore
        self.watcherService = watcherService
        self.scanner = scanner
        self.manifestURL = manifestURL ?? Self.defaultManifestURL()
        loadPersistedFolders()
        if seedDefaultFolder {
            checkAndSeedDefaultFolderIfNeeded()
        }
    }

    // MARK: - Lifecycle

    /// Starts monitoring all enabled watched folders.
    func startMonitoring() {
        for folder in folders where folder.isEnabled {
            startWatchingFolder(folder)
        }
        Task {
            await rescanAll()
        }
    }

    /// Stops all background monitoring streams.
    func stopMonitoring() {
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
        let folderID = folder.id
        #if os(macOS)
        if activeScopedFolders[folderID] == nil {
            var isStale = false
            if let bookmark = folder.bookmarkData,
               let resolved = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) {
                if resolved.startAccessingSecurityScopedResource() {
                    activeScopedFolders[folderID] = resolved
                }
            } else if folder.url.startAccessingSecurityScopedResource() {
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

    func addFolder(url: URL, autoIngest: Bool = true) async {
        let cleanURL = url.resolvingSymlinksInPath().standardizedFileURL
        if let existing = folders.first(where: { $0.url.standardizedFileURL == cleanURL }) {
            if !existing.isEnabled {
                toggleFolder(id: existing.id)
            }
            return
        }

#if os(macOS)
        let bookmarkOptions: URL.BookmarkCreationOptions = .withSecurityScope
#else
        let bookmarkOptions: URL.BookmarkCreationOptions = []
#endif
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

    func removeFolder(id: UUID) {
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

    func toggleFolder(id: UUID) {
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

    func setAutoIngest(id: UUID, autoIngest: Bool) {
        guard let index = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[index].autoIngest = autoIngest
        persistFolders()
    }

    // MARK: - Scanning & Ingestion

    func rescanAll() async {
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

    func rescanFolder(id: UUID) async {
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
        var isStale = false
#if os(macOS)
        let resolveOptions: URL.BookmarkResolutionOptions = .withSecurityScope
#else
        let resolveOptions: URL.BookmarkResolutionOptions = []
#endif
        let targetURL: URL
        var hasSecurityScope = false

        if let existingScope = activeScopedFolders[folder.id] {
            targetURL = existingScope
        } else if let bookmark = folder.bookmarkData,
           let resolved = try? URL(resolvingBookmarkData: bookmark, options: resolveOptions, relativeTo: nil, bookmarkDataIsStale: &isStale) {
            targetURL = resolved
            hasSecurityScope = targetURL.startAccessingSecurityScopedResource()
            if hasSecurityScope {
                activeScopedFolders[folder.id] = targetURL
            }
        } else {
            targetURL = folder.url
            hasSecurityScope = targetURL.startAccessingSecurityScopedResource()
            if hasSecurityScope {
                activeScopedFolders[folder.id] = targetURL
            }
        }

        guard FileManager.default.fileExists(atPath: targetURL.path) else {
            return 0
        }

        // Ensure localStore is hydrated before diffing
        await localStore.loadIfNeeded()

        let targetPath = targetURL.standardizedFileURL.path
        let tracksInFolder = localStore.tracks.filter { track in
            track.fileURL.standardizedFileURL.path.hasPrefix(targetPath)
        }

        let cache = await LocalFingerprintRegistry.shared.assetCache
        let result = await scanner.reconcileFolder(
            targetURL: targetURL,
            existingTracksInFolder: tracksInFolder,
            assetCache: cache
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

    private static func defaultManifestURL() -> URL? {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = support.appendingPathComponent("MSRU", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("watched_folders.json")
    }

    private func persistFolders() {
        guard let manifestURL else { return }
        if let data = try? JSONEncoder().encode(folders) {
            try? data.write(to: manifestURL, options: .atomic)
        }
    }

    private func loadPersistedFolders() {
        guard let manifestURL,
              let data = try? Data(contentsOf: manifestURL),
              let decoded = try? JSONDecoder().decode([WatchedFolder].self, from: data) else {
            return
        }
        self.folders = decoded
    }

    // MARK: - Default Folder Seeding

    private func checkAndSeedDefaultFolderIfNeeded() {
        let path = Self.defaultUserWatchedPath
        guard FileManager.default.fileExists(atPath: path) else { return }

        let defaultURL = URL(fileURLWithPath: path).standardizedFileURL
        let exists = folders.contains(where: { $0.url.standardizedFileURL.path == defaultURL.path })
        if !exists {
#if os(macOS)
            let bookmarkOptions: URL.BookmarkCreationOptions = .withSecurityScope
#else
            let bookmarkOptions: URL.BookmarkCreationOptions = []
#endif
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

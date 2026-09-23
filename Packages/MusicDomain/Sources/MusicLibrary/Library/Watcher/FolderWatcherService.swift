//
//  FolderWatcherService.swift
//  MSRU
//
//  Created for Task 31: Watched Folders background monitoring and continuous ingestion.
//

import Foundation
import MusicDomain
#if os(macOS)
import CoreServices
#endif

// MARK: - Watched Folder Model

/// A directory configured for continuous background file monitoring and ingestion.
public struct WatchedFolder: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var url: URL
    public var bookmarkData: Data?
    public var isEnabled: Bool
    public var autoIngest: Bool
    public var lastScannedAt: Date?
    public var trackCount: Int

    public init(
        id: UUID = UUID(),
        url: URL,
        bookmarkData: Data? = nil,
        isEnabled: Bool = true,
        autoIngest: Bool = true,
        lastScannedAt: Date? = nil,
        trackCount: Int = 0
    ) {
        self.id = id
        self.url = url
        self.bookmarkData = bookmarkData
        self.isEnabled = isEnabled
        self.autoIngest = autoIngest
        self.lastScannedAt = lastScannedAt
        self.trackCount = trackCount
    }

    public var displayName: String {
        url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
    }

    public var path: String {
        url.path
    }

    public var isNetworkVolume: Bool {
        !SecurityScopePolicy.isLocalVolume(url)
    }
}

// MARK: - Watched Folder Scanner & Reconciliation

nonisolated public struct FolderReconciliationResult: Sendable {
    public let newTracks: [LocalTrack]
    public let modifiedTracks: [LocalTrack]
    public let deletedTrackPaths: [String]
    public let totalScannedCount: Int
    public let discoveredCount: Int

    public init(
        newTracks: [LocalTrack],
        modifiedTracks: [LocalTrack] = [],
        deletedTrackPaths: [String] = [],
        totalScannedCount: Int,
        discoveredCount: Int
    ) {
        self.newTracks = newTracks
        self.modifiedTracks = modifiedTracks
        self.deletedTrackPaths = deletedTrackPaths
        self.totalScannedCount = totalScannedCount
        self.discoveredCount = discoveredCount
    }
}

/// Dedicated actor performing filesystem directory traversal and audio metadata parsing off the main thread.
public actor WatchedFolderScanner {
    public init() {}

    /// Recursively collects all supported audio file URLs within a directory.
    public func collectAudioFiles(at directory: URL) -> [URL] {
        var results: [URL] = []
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey]

        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        while let fileURL = enumerator.nextObject() as? URL {
            let pathExt = fileURL.pathExtension.lowercased()
            if LocalAudioFormatSupport.supports(extension: pathExt) {
                results.append(fileURL)
            }
        }
        return results
    }

    /// Reconciles disk files against known tracks in this folder.
    /// Runs off @MainActor. Unchanged tracks produce 0 metadata reads and 0 track emissions.
    public func reconcileFolder(
        targetURL: URL,
        existingTracksInFolder: [LocalTrack],
        assetCache: [String: AssetFingerprintEntry] = [:],
        signatures: [String: AudioFileSignature] = [:]
    ) async -> FolderReconciliationResult {
        let allAudioURLs = collectAudioFiles(at: targetURL)
        let existingMap = Dictionary(
            uniqueKeysWithValues: existingTracksInFolder.map { ($0.fileURL.standardizedFileURL.path, $0) }
        )

        var currentPaths = Set<String>()
        var newAudioURLs: [URL] = []
        var modifiedAudioURLs: [URL] = []

        for audioURL in allAudioURLs {
            let stdPath = audioURL.standardizedFileURL.path
            currentPaths.insert(stdPath)

            if existingMap[stdPath] == nil {
                newAudioURLs.append(audioURL)
            } else {
                let canonicalPath = audioURL.resolvingSymlinksInPath().standardizedFileURL.path
                if let sig = signatures[canonicalPath] {
                    if !sig.matches(fileURL: audioURL) {
                        modifiedAudioURLs.append(audioURL)
                    }
                } else if let cached = assetCache[canonicalPath] {
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: canonicalPath),
                       let size = attrs[.size] as? Int64,
                       let modDate = attrs[.modificationDate] as? Date,
                       cached.fileSize == size,
                       abs(cached.modificationTime - modDate.timeIntervalSince1970) < 1.0 {
                        // Unmodified
                    } else {
                        modifiedAudioURLs.append(audioURL)
                    }
                }
            }
        }

        // Deleted tracks: present in library under this folder, but absent on disk
        var deletedPaths: [String] = []
        for (existingPath, _) in existingMap {
            if !currentPaths.contains(existingPath) {
                deletedPaths.append(existingPath)
            }
        }

        // Parse metadata off @MainActor
        var newTracks: [LocalTrack] = []
        for url in newAudioURLs {
            do {
                let track = try await FileLocalLibraryRepository.readTrack(from: url)
                newTracks.append(track)
            } catch {
                print("Scanner failed to read new track:", url.lastPathComponent, error.localizedDescription)
            }
            await Task.yield()
        }

        var modifiedTracks: [LocalTrack] = []
        for url in modifiedAudioURLs {
            do {
                let track = try await FileLocalLibraryRepository.readTrack(from: url)
                modifiedTracks.append(track)
            } catch {
                print("Scanner failed to read modified track:", url.lastPathComponent, error.localizedDescription)
            }
            await Task.yield()
        }

        return FolderReconciliationResult(
            newTracks: newTracks,
            modifiedTracks: modifiedTracks,
            deletedTrackPaths: deletedPaths,
            totalScannedCount: allAudioURLs.count,
            discoveredCount: newTracks.count + modifiedTracks.count
        )
    }
}

// MARK: - Folder Watcher Driver

#if os(macOS)
private final class FSEventStreamHolder: @unchecked Sendable {
    nonisolated(unsafe) var streamRef: FSEventStreamRef?

    public nonisolated func stop() {
        guard let stream = streamRef else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.streamRef = nil
    }

    deinit {
        stop()
    }
}
#endif

/// Abstract driver protocol for monitoring file system changes in a folder.
@MainActor
public protocol FolderWatcherDriver: AnyObject {
    func startMonitoring(path: String, onChange: @escaping @Sendable () -> Void)
    func stopMonitoring()
}

#if os(macOS)
/// Native macOS FSEvents-based file system watcher driver.
@MainActor
public final class FSEventsWatcherDriver: FolderWatcherDriver {
    private let holder = FSEventStreamHolder()
    private let latency: TimeInterval

    public init(latency: TimeInterval = 1.5) {
        self.latency = latency
    }

    public func startMonitoring(path: String, onChange: @escaping @Sendable () -> Void) {
        stopMonitoring()
        guard !path.isEmpty else { return }

        final class CallbackBox: @unchecked Sendable {
            let callback: @Sendable () -> Void
            init(_ callback: @escaping @Sendable () -> Void) {
                self.callback = callback
            }
        }

        let box = CallbackBox(onChange)
        let info = Unmanaged.passRetained(box).toOpaque()

        var context = FSEventStreamContext(
            version: 0,
            info: info,
            retain: nil,
            release: { ptr in
                guard let ptr = ptr else { return }
                Unmanaged<CallbackBox>.fromOpaque(ptr).release()
            },
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { (streamRef, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds) in
            guard let clientCallBackInfo = clientCallBackInfo else { return }
            let boxed = Unmanaged<CallbackBox>.fromOpaque(clientCallBackInfo).takeUnretainedValue()
            DispatchQueue.main.async {
                boxed.callback()
            }
        }

        let pathsToWatch = [path] as CFArray
        let flags = UInt32(
            kFSEventStreamCreateFlagUseCFTypes |
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagNoDefer
        )

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            CFTimeInterval(latency),
            flags
        ) else {
            Unmanaged<CallbackBox>.fromOpaque(info).release()
            return
        }

        holder.streamRef = stream
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
    }

    public func stopMonitoring() {
        holder.stop()
    }
}
#endif

/// In-memory simulated file system watcher for unit tests and non-macOS platforms.
@MainActor
public final class SimulatedFolderWatcherDriver: FolderWatcherDriver {
    private var callback: (@Sendable () -> Void)?

    public func startMonitoring(path: String, onChange: @escaping @Sendable () -> Void) {
        self.callback = onChange
    }

    public func stopMonitoring() {
        self.callback = nil
    }

    public func triggerChange() {
        callback?()
    }

    nonisolated public init() {}
}

// MARK: - Folder Watcher Service

/// Service managing the active watcher drivers for all registered watched folders.
@MainActor
public final class FolderWatcherService {
    private var drivers: [UUID: any FolderWatcherDriver] = [:]
    private let driverFactory: @MainActor () -> any FolderWatcherDriver

    public init(driverFactory: (@MainActor () -> any FolderWatcherDriver)? = nil) {
        if let driverFactory {
            self.driverFactory = driverFactory
        } else {
            #if os(macOS)
            self.driverFactory = { FSEventsWatcherDriver() }
            #else
            self.driverFactory = { SimulatedFolderWatcherDriver() }
            #endif
        }
    }

    public func startWatching(folder: WatchedFolder, onChange: @escaping @Sendable () -> Void) {
        stopWatching(id: folder.id)
        guard folder.isEnabled else { return }

        let driver = driverFactory()
        driver.startMonitoring(path: folder.url.path, onChange: onChange)
        drivers[folder.id] = driver
    }

    public func stopWatching(id: UUID) {
        if let driver = drivers.removeValue(forKey: id) {
            driver.stopMonitoring()
        }
    }

    public func stopAll() {
        for driver in drivers.values {
            driver.stopMonitoring()
        }
        drivers.removeAll()
    }

    public func isWatching(id: UUID) -> Bool {
        drivers[id] != nil
    }
}

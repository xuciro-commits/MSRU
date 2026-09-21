//
//  FolderWatcherService.swift
//  MSRU
//
//  Created for Task 31: Watched Folders background monitoring and continuous ingestion.
//

import Foundation
#if os(macOS)
import CoreServices

private final class FSEventStreamHolder: @unchecked Sendable {
    nonisolated(unsafe) var streamRef: FSEventStreamRef?

    nonisolated func stop() {
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
protocol FolderWatcherDriver: AnyObject {
    func startMonitoring(path: String, onChange: @escaping @Sendable () -> Void)
    func stopMonitoring()
}

#if os(macOS)
/// Native macOS FSEvents-based file system watcher driver.
@MainActor
final class FSEventsWatcherDriver: FolderWatcherDriver {
    private let holder = FSEventStreamHolder()
    private let latency: TimeInterval

    init(latency: TimeInterval = 1.5) {
        self.latency = latency
    }

    func startMonitoring(path: String, onChange: @escaping @Sendable () -> Void) {
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

    func stopMonitoring() {
        holder.stop()
    }
}
#endif

/// In-memory simulated file system watcher for unit tests and non-macOS platforms.
@MainActor
final class SimulatedFolderWatcherDriver: FolderWatcherDriver {
    private var callback: (@Sendable () -> Void)?

    init() {}

    func startMonitoring(path: String, onChange: @escaping @Sendable () -> Void) {
        self.callback = onChange
    }

    func stopMonitoring() {
        self.callback = nil
    }

    func triggerChange() {
        callback?()
    }
}

/// Service managing the active watcher drivers for all registered watched folders.
@MainActor
final class FolderWatcherService {
    private var drivers: [UUID: any FolderWatcherDriver] = [:]
    private let driverFactory: @MainActor () -> any FolderWatcherDriver

    init(driverFactory: (@MainActor () -> any FolderWatcherDriver)? = nil) {
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

    func startWatching(folder: WatchedFolder, onChange: @escaping @Sendable () -> Void) {
        stopWatching(id: folder.id)
        guard folder.isEnabled else { return }

        let driver = driverFactory()
        driver.startMonitoring(path: folder.url.path, onChange: onChange)
        drivers[folder.id] = driver
    }

    func stopWatching(id: UUID) {
        if let driver = drivers.removeValue(forKey: id) {
            driver.stopMonitoring()
        }
    }

    func stopAll() {
        for driver in drivers.values {
            driver.stopMonitoring()
        }
        drivers.removeAll()
    }

    func isWatching(id: UUID) -> Bool {
        drivers[id] != nil
    }
}

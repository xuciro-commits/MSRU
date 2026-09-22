//
//  MediaImagePipeline.swift
//  MSRU
//
//  Canonical 3-Tier Media Image Pipeline (L1 Memory Cache, L2 Size-Capped Disk Thumbnail Cache, L3 Content-Addressed / Remote Store)
//  with pixel-bucket downsampling, display scale awareness, viewport prefetching, and deduplicated in-flight loading.
//

import Foundation
import ImageIO
import CryptoKit

#if canImport(AppKit)
import AppKit
public typealias PlatformImage = NSImage
#elseif canImport(UIKit)
import UIKit
public typealias PlatformImage = UIImage
#endif

// MARK: - Media Image Reference

/// Canonical domain reference for any musical image asset (album artwork, artist portrait, playlist cover, station logo).
/// Domain entities MUST only hold this reference, never raw image bytes or decoded bitmap objects.
nonisolated public struct MediaImageReference: Hashable, Codable, Sendable {

    public enum Source: Hashable, Codable, Sendable {
        case local(relativePath: String)
        case remote(url: URL)
    }

    public let source: Source
    public let revision: UInt64

    public init(source: Source, revision: UInt64 = 0) {
        self.source = source
        self.revision = revision
    }

    public init(relativePath: String, revision: UInt64 = 0) {
        self.source = .local(relativePath: relativePath)
        self.revision = revision
    }

    public init(url: URL, revision: UInt64 = 0) {
        self.source = .remote(url: url)
        self.revision = revision
    }

    public init?(string: String?, revision: UInt64 = 0) {
        guard let string = string?.trimmingCharacters(in: .whitespacesAndNewlines), !string.isEmpty else {
            return nil
        }
        if string.hasPrefix("http://") || string.hasPrefix("https://"), let url = URL(string: string) {
            self.source = .remote(url: url)
        } else {
            self.source = .local(relativePath: string)
        }
        self.revision = revision
    }

    public var rawString: String {
        switch source {
        case .local(let relativePath):
            return relativePath
        case .remote(let url):
            return url.absoluteString
        }
    }
}

// MARK: - Pixel Buckets

/// Normalized target pixel dimension buckets.
/// Prevents fragmentation of derived thumbnails on disk by snapping arbitrary view dimensions to standard buckets.
nonisolated public enum PixelBucket: Int, Sendable, CaseIterable {
    case px64 = 64
    case px128 = 128
    case px256 = 256
    case px512 = 512
    case px1024 = 1024
    case original = 0

    // Backward compatibility aliases for existing call sites:
    public static let pt32 = PixelBucket.px64
    public static let pt64 = PixelBucket.px128
    public static let pt128 = PixelBucket.px256
    public static let pt256 = PixelBucket.px512

    public var maxPixelDimension: Int { rawValue }

    public static func bucket(for requestedPixels: Int) -> PixelBucket {
        if requestedPixels <= 64 { return .px64 }
        if requestedPixels <= 128 { return .px128 }
        if requestedPixels <= 256 { return .px256 }
        if requestedPixels <= 512 { return .px512 }
        return .px1024
    }

    public static func bucket(for pointSize: CGSize, scale: CGFloat = 2.0) -> PixelBucket {
        let maxPoint = max(pointSize.width, pointSize.height)
        let requestedPixels = Int(ceil(maxPoint * scale))
        return bucket(for: requestedPixels)
    }
}

// Backward compatibility typealiases
public typealias ArtworkLoader = MediaImagePipeline
public typealias ArtworkPipeline = MediaImagePipeline

// MARK: - Canonical Media Image Pipeline

/// Unified actor responsible for media image acquisition, 3-tier caching, downsampling,
/// bounded disk LRU eviction, and shared in-flight request deduplication.
public actor MediaImagePipeline: Sendable {

    public static let shared = MediaImagePipeline()

    // L1: Decoded in-memory NSCache (Thread-safe NSCache allows synchronous 0ms L1 fast-path)
    nonisolated(unsafe) private let memoryCache = NSCache<NSString, PlatformImage>()

    // L2: Disk thumbnail cache configuration
    private let diskCacheURL: URL
    private let maxDiskBytes: Int
    private var writeCounter: Int = 0

    // In-flight request deduplication
    private var inFlightTasks: [String: Task<PlatformImage?, Never>] = [:]

    // Custom or default URLSession for remote assets
    private let urlSession: URLSession

    public init(
        maxMemoryBytes: Int = 40 * 1024 * 1024,
        maxCount: Int = 500,
        maxDiskBytes: Int = 256 * 1024 * 1024,
        urlSession: URLSession = .shared
    ) {
        self.memoryCache.totalCostLimit = maxMemoryBytes
        self.memoryCache.countLimit = maxCount
        self.maxDiskBytes = maxDiskBytes
        self.urlSession = urlSession

        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.diskCacheURL = caches.appendingPathComponent("MSRU/Thumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }

    // MARK: - Primary Loading API

    /// Loads a downsampled thumbnail for a typed MediaImageReference with 3-tier fallback.
    public func loadThumbnail(
        for reference: MediaImageReference,
        bucket: PixelBucket = .px128,
        scale: CGFloat = 2.0
    ) async -> PlatformImage? {
        let cacheKey = Self.makeCacheKey(reference: reference, bucket: bucket, scale: scale)

        // 1. Check L1 Memory Cache
        if let memoryImage = memoryCache.object(forKey: cacheKey as NSString) {
            return memoryImage
        }

        // 2. In-flight task deduplication
        if let existingTask = inFlightTasks[cacheKey] {
            return await existingTask.value
        }

        let task = Task<PlatformImage?, Never> { [weak self] () -> PlatformImage? in
            guard !Task.isCancelled else { return nil }

            // 3. Check L2 Disk Thumbnail Cache
            if let diskImage = await self?.loadFromDiskCache(forKey: cacheKey) {
                await self?.saveToMemoryCache(diskImage, forKey: cacheKey)
                return diskImage
            }

            guard !Task.isCancelled else { return nil }

            // 4. Resolve L3 Raw Image Data (CAS local store or remote network)
            guard let rawData = await self?.resolveRawData(for: reference) else {
                return nil
            }

            guard !Task.isCancelled else { return nil }

            // 5. Downsample using ImageIO
            let pixelSize = bucket == .original ? 1200 : bucket.maxPixelDimension
            guard let decoded = Self.decodeDownsampledImage(from: rawData, maxPixelSize: pixelSize) else {
                return nil
            }

            // Save to L2 disk cache and L1 memory cache
            await self?.saveToDiskCache(decoded, forKey: cacheKey)
            await self?.saveToMemoryCache(decoded, forKey: cacheKey)

            return decoded
        }

        inFlightTasks[cacheKey] = task
        let result = await task.value
        inFlightTasks.removeValue(forKey: cacheKey)
        return result
    }

    /// Convenience overload accepting string references (local relative path or remote URL).
    public func loadThumbnail(
        for reference: String,
        bucket: PixelBucket = .px128,
        scale: CGFloat = 2.0
    ) async -> PlatformImage? {
        guard let ref = MediaImageReference(string: reference) else { return nil }
        return await loadThumbnail(for: ref, bucket: bucket, scale: scale)
    }

    /// Convenience overload accepting remote URL directly.
    public func loadThumbnail(
        for url: URL,
        bucket: PixelBucket = .px128,
        scale: CGFloat = 2.0
    ) async -> PlatformImage? {
        let ref = MediaImageReference(url: url)
        return await loadThumbnail(for: ref, bucket: bucket, scale: scale)
    }

    /// Convenience overload accepting explicit target layout size (e.g. for SwiftUI views).
    public func loadThumbnail(
        for reference: String,
        targetSize: CGSize,
        scale: CGFloat = 2.0
    ) async -> PlatformImage? {
        guard let ref = MediaImageReference(string: reference) else { return nil }
        let bucket = PixelBucket.bucket(for: targetSize, scale: scale)
        return await loadThumbnail(for: ref, bucket: bucket, scale: scale)
    }

    /// Convenience overload for MediaImageReference with explicit target layout size.
    public func loadThumbnail(
        for reference: MediaImageReference,
        targetSize: CGSize,
        scale: CGFloat = 2.0
    ) async -> PlatformImage? {
        let bucket = PixelBucket.bucket(for: targetSize, scale: scale)
        return await loadThumbnail(for: reference, bucket: bucket, scale: scale)
    }

    /// Loads the full-resolution artwork image.
    public func loadFullImage(for reference: String) async -> PlatformImage? {
        await loadThumbnail(for: reference, bucket: .original)
    }

    // MARK: - Synchronous L1 Cache Hit (0ms / Zero Async Spawning)

    /// Synchronously retrieves a cached thumbnail from L1 memory cache if already resident.
    /// Thread-safe and zero-latency (0ms), avoiding actor hopping and asynchronous task spawning.
    nonisolated public func cachedThumbnail(
        for reference: MediaImageReference,
        bucket: PixelBucket = .px128,
        scale: CGFloat = 2.0
    ) -> PlatformImage? {
        let cacheKey = Self.makeCacheKey(reference: reference, bucket: bucket, scale: scale)
        return memoryCache.object(forKey: cacheKey as NSString)
    }

    /// Synchronously retrieves a cached thumbnail from L1 memory cache for explicit target layout size.
    nonisolated public func cachedThumbnail(
        for reference: MediaImageReference,
        targetSize: CGSize,
        scale: CGFloat = 2.0
    ) -> PlatformImage? {
        let bucket = PixelBucket.bucket(for: targetSize, scale: scale)
        return cachedThumbnail(for: reference, bucket: bucket, scale: scale)
    }

    /// Synchronously retrieves a cached thumbnail from L1 memory cache for string reference.
    nonisolated public func cachedThumbnail(
        for reference: String?,
        targetSize: CGSize,
        scale: CGFloat = 2.0
    ) -> PlatformImage? {
        guard let reference, let ref = MediaImageReference(string: reference) else { return nil }
        return cachedThumbnail(for: ref, targetSize: targetSize, scale: scale)
    }

    // MARK: - Viewport Prefetching

    /// Renderer prefetch API to prime nearby visible items during scrolling.
    public nonisolated func prefetch(
        references: [String],
        bucket: PixelBucket = .px128,
        scale: CGFloat = 2.0
    ) {
        Task {
            for refString in references {
                guard let ref = MediaImageReference(string: refString) else { continue }
                _ = await self.loadThumbnail(for: ref, bucket: bucket, scale: scale)
            }
        }
    }

    // MARK: - Cache Management & Eviction

    public func clearCache() {
        clearMemoryCache()
        clearDiskCache()
    }

    public func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }

    public func clearDiskCache() {
        try? FileManager.default.removeItem(at: diskCacheURL)
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }

    // MARK: - Private Helpers

    private func resolveRawData(for reference: MediaImageReference) async -> Data? {
        switch reference.source {
        case .local(let relativePath):
            return LocalArtworkStorage.shared.loadArtwork(relativePath: relativePath)
        case .remote(let url):
            do {
                let (data, response) = try await urlSession.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    return nil
                }
                // Cache into L3 CAS for offline persistence
                _ = LocalArtworkStorage.shared.storeArtwork(data)
                return data
            } catch {
                return nil
            }
        }
    }

    nonisolated private static func makeCacheKey(reference: MediaImageReference, bucket: PixelBucket, scale: CGFloat) -> String {
        let raw = reference.rawString
        let baseHash: String
        if raw.hasPrefix("http://") || raw.hasPrefix("https://") {
            let digest = SHA256.hash(data: Data(raw.utf8))
            baseHash = digest.compactMap { String(format: "%02x", $0) }.joined()
        } else {
            baseHash = raw.components(separatedBy: "/").last?.replacingOccurrences(of: ".jpg", with: "") ?? raw
        }
        return "\(baseHash)_\(bucket.maxPixelDimension)_\(Int(scale))x_r\(reference.revision)"
    }

    private func saveToMemoryCache(_ image: PlatformImage, forKey key: String) {
        #if canImport(AppKit)
        let cost: Int
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            cost = cgImage.bytesPerRow * cgImage.height
        } else {
            cost = Int(image.size.width * image.size.height * 4)
        }
        #elseif canImport(UIKit)
        let cost: Int
        if let cgImage = image.cgImage {
            cost = cgImage.bytesPerRow * cgImage.height
        } else {
            cost = Int(image.size.width * image.size.height * image.scale * 4)
        }
        #endif
        memoryCache.setObject(image, forKey: key as NSString, cost: cost)
    }

    private func loadFromDiskCache(forKey key: String) -> PlatformImage? {
        let fileURL = diskCacheURL.appendingPathComponent("\(key).jpg")
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        guard data.count >= 16 else {
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }
        // Touch modification date for LRU tracking
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)

        #if canImport(AppKit)
        return NSImage(data: data)
        #elseif canImport(UIKit)
        return UIImage(data: data)
        #endif
    }

    private func saveToDiskCache(_ image: PlatformImage, forKey key: String) {
        let fileURL = diskCacheURL.appendingPathComponent("\(key).jpg")
        guard !FileManager.default.fileExists(atPath: fileURL.path) else { return }

        #if canImport(AppKit)
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else {
            return
        }
        try? jpeg.write(to: fileURL, options: .atomic)
        #elseif canImport(UIKit)
        guard let jpeg = image.jpegData(compressionQuality: 0.85) else { return }
        try? jpeg.write(to: fileURL, options: .atomic)
        #endif

        writeCounter += 1
        if writeCounter >= 50 {
            writeCounter = 0
            pruneDiskCacheIfNeeded()
        }
    }

    /// Enforces size-capped LRU eviction on L2 disk thumbnail cache.
    /// Prunes oldest accessed files when total size exceeds maxDiskBytes.
    private func pruneDiskCacheIfNeeded() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: diskCacheURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: .skipsHiddenFiles
        ) else { return }

        var totalSize: Int = 0
        var fileEntries: [(url: URL, date: Date, size: Int)] = []

        for file in files {
            guard let values = try? file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                  let size = values.fileSize else { continue }
            totalSize += size
            let date = values.contentModificationDate ?? Date.distantPast
            fileEntries.append((url: file, date: date, size: size))
        }

        guard totalSize > maxDiskBytes else { return }

        // Sort oldest first
        fileEntries.sort { $0.date < $1.date }

        let targetSize = Int(Double(maxDiskBytes) * 0.75)
        var currentSize = totalSize

        for entry in fileEntries {
            guard currentSize > targetSize else { break }
            try? FileManager.default.removeItem(at: entry.url)
            currentSize -= entry.size
        }
    }

    private static func decodeDownsampledImage(from data: Data, maxPixelSize: Int) -> PlatformImage? {
        // Enforce minimum header size to avoid ImageIO IIOScanner seeking past EOF on corrupt or truncated data
        guard data.count >= 16 else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            return nil
        }

        let status = CGImageSourceGetStatus(source)
        guard status == .statusComplete || status == .statusIncomplete,
              CGImageSourceGetCount(source) > 0 else {
            return nil
        }

        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else {
            return nil
        }

        #if canImport(AppKit)
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        #elseif canImport(UIKit)
        return UIImage(cgImage: cgImage)
        #endif
    }
}

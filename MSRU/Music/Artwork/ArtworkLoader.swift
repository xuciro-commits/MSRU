//
//  ArtworkLoader.swift
//  MSRU
//
//  3-Tier Artwork Pipeline (L1 In-Memory NSCache, L2 Disk Thumbnail Cache, L3 Content-Addressed Store)
//  with pixel-bucket downsampling, display scale awareness, renderer prefetching, and deduplicated in-flight loading.
//

import Foundation
import ImageIO
#if canImport(AppKit)
import AppKit
public typealias PlatformImage = NSImage
#elseif canImport(UIKit)
import UIKit
public typealias PlatformImage = UIImage
#endif

nonisolated public enum PixelBucket: Int, Sendable, CaseIterable {
    case pt32 = 64      // 32pt @ 2x
    case pt64 = 128     // 64pt @ 2x
    case pt128 = 256    // 128pt @ 2x
    case pt256 = 512    // 256pt @ 2x
    case original = 0

    nonisolated public var maxPixelDimension: Int { rawValue }
}

public typealias ArtworkPipeline = ArtworkLoader

/// Unified, thread-safe actor responsible for on-demand artwork thumbnail generation,
/// 3-tier caching (L1 RAM -> L2 Disk -> L3 Local Store), in-flight deduplication, and prefetching.
public actor ArtworkLoader: Sendable {

    public static let shared = ArtworkLoader()

    // L1: Decoded in-memory NSCache (bounded)
    private let memoryCache = NSCache<NSString, PlatformImage>()
    private let diskCacheURL: URL
    private var inFlightTasks: [String: Task<PlatformImage?, Never>] = [:]

    public init(maxMemoryBytes: Int = 40 * 1024 * 1024, maxCount: Int = 500) {
        memoryCache.totalCostLimit = maxMemoryBytes
        memoryCache.countLimit = maxCount

        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.diskCacheURL = caches.appendingPathComponent("MSRU/Thumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }

    /// Primary entry point: loads downsampled thumbnail with 3-tier fallback.
    public func loadThumbnail(
        for reference: String,
        bucket: PixelBucket = .pt64,
        scale: CGFloat = 2.0
    ) async -> PlatformImage? {
        let cleanRef = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanRef.isEmpty else { return nil }

        let cacheKey = makeCacheKey(reference: cleanRef, bucket: bucket, scale: scale)

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

            // 4. Fallback to L3 Content-Addressed Original ArtworkStore
            guard let rawData = LocalArtworkStorage.shared.loadArtwork(relativePath: cleanRef) else {
                return nil
            }

            guard !Task.isCancelled else { return nil }

            // Downsample using CGImageSource
            let pixelSize = bucket == .original ? 1200 : Int(CGFloat(bucket.maxPixelDimension) * (scale / 2.0))
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

    /// Convenience overload accepting targetSize (e.g. for SwiftUI views)
    public func loadThumbnail(for reference: String, targetSize: CGSize) async -> PlatformImage? {
        let maxDim = max(targetSize.width, targetSize.height)
        let bucket: PixelBucket
        if maxDim <= 32 {
            bucket = .pt32
        } else if maxDim <= 64 {
            bucket = .pt64
        } else if maxDim <= 128 {
            bucket = .pt128
        } else {
            bucket = .pt256
        }
        return await loadThumbnail(for: reference, bucket: bucket)
    }

    /// Asynchronously loads the full-resolution artwork image.
    public func loadFullImage(for reference: String) async -> PlatformImage? {
        await loadThumbnail(for: reference, bucket: .original)
    }

    /// Renderer prefetch API to prime nearby visible items during scrolling.
    public func prefetch(
        references: [String],
        bucket: PixelBucket = .pt64,
        scale: CGFloat = 2.0
    ) {
        for ref in references {
            let cleanRef = ref.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanRef.isEmpty else { continue }
            let cacheKey = makeCacheKey(reference: cleanRef, bucket: bucket, scale: scale)
            if memoryCache.object(forKey: cacheKey as NSString) == nil && inFlightTasks[cacheKey] == nil {
                Task {
                    _ = await self.loadThumbnail(for: cleanRef, bucket: bucket, scale: scale)
                }
            }
        }
    }

    /// Purges all in-memory artwork thumbnails from cache.
    public func clearCache() {
        memoryCache.removeAllObjects()
    }

    // MARK: - Cache Helpers

    private func makeCacheKey(reference: String, bucket: PixelBucket, scale: CGFloat) -> String {
        let baseHash = reference.components(separatedBy: "/").last?.replacingOccurrences(of: ".jpg", with: "") ?? reference
        return "\(baseHash)_\(bucket.maxPixelDimension)_\(Int(scale))x"
    }

    private func saveToMemoryCache(_ image: PlatformImage, forKey key: String) {
        #if canImport(AppKit)
        let cost = Int(image.size.width * image.size.height * 4)
        #elseif canImport(UIKit)
        let cost = Int(image.size.width * image.size.height * image.scale * 4)
        #endif
        memoryCache.setObject(image, forKey: key as NSString, cost: cost)
    }

    private func loadFromDiskCache(forKey key: String) -> PlatformImage? {
        let fileURL = diskCacheURL.appendingPathComponent("\(key).jpg")
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
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
    }

    private static func decodeDownsampledImage(from data: Data, maxPixelSize: Int) -> PlatformImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
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

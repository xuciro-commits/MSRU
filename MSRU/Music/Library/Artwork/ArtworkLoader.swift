//
//  ArtworkLoader.swift
//  MSRU
//
//  Created for On-Demand, Cancellable, Downsampled Artwork Thumbnail Loading.
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

/// Thread-safe actor responsible for on-demand artwork loading, downsampled thumbnail generation,
/// in-flight deduplication, and bounded memory caching.
public actor ArtworkLoader: Sendable {

    public static let shared = ArtworkLoader()

    private let cache = NSCache<NSString, PlatformImage>()
    private var inFlightTasks: [String: Task<PlatformImage?, Never>] = [:]

    public init(maxMemoryBytes: Int = 40 * 1024 * 1024, maxCount: Int = 300) {
        cache.totalCostLimit = maxMemoryBytes
        cache.countLimit = maxCount
    }

    /// Asynchronously loads a downsampled thumbnail for the given artwork reference.
    /// Consolidated to unified 3-tier ArtworkPipeline.
    public func loadThumbnail(for reference: String, targetSize: CGSize = CGSize(width: 160, height: 160)) async -> PlatformImage? {
        let bucket: PixelBucket
        if targetSize.width <= 32 {
            bucket = .pt32
        } else if targetSize.width <= 64 {
            bucket = .pt64
        } else if targetSize.width <= 128 {
            bucket = .pt128
        } else {
            bucket = .pt256
        }
        return await ArtworkPipeline.shared.loadThumbnail(for: reference, bucket: bucket)
    }

    /// Asynchronously loads the full-resolution artwork image.
    /// Used only for high-resolution displays such as NowPlaying Canvas or Track Inspector.
    public func loadFullImage(for reference: String) async -> PlatformImage? {
        let cleanRef = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanRef.isEmpty else { return nil }

        let cacheKey = "\(cleanRef)@full"

        if let cached = cache.object(forKey: cacheKey as NSString) {
            return cached
        }

        guard let data = LocalArtworkStorage.shared.loadArtwork(relativePath: cleanRef) else {
            return nil
        }

        #if canImport(AppKit)
        guard let image = NSImage(data: data) else { return nil }
        #elseif canImport(UIKit)
        guard let image = UIImage(data: data) else { return nil }
        #endif

        cache.setObject(image, forKey: cacheKey as NSString, cost: data.count)
        return image
    }

    /// Purges all in-memory artwork thumbnails and full-size images from cache.
    public func clearCache() {
        cache.removeAllObjects()
    }

    private func storeInCache(_ image: PlatformImage, forKey key: String, targetSize: CGSize) {
        // Approximate bitmap cost: width * height * 4 bytes per pixel * 4 (Retina @2x)
        let cost = Int(targetSize.width * targetSize.height * 16)
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }

    // MARK: - Downsampling Core

    private static func createDownsampledThumbnail(from data: Data, targetSize: CGSize) -> PlatformImage? {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        let maxPixelSize = max(targetSize.width, targetSize.height) * 2.0 // @2x Retina density
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxPixelSize)
        ]

        guard let thumbnailCG = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }

        #if canImport(AppKit)
        return NSImage(cgImage: thumbnailCG, size: targetSize)
        #elseif canImport(UIKit)
        return UIImage(cgImage: thumbnailCG)
        #endif
    }
}

//
//  ArtworkLoaderTests.swift
//  MSRUTests
//
//  Created for ArtworkLoader downsampling, in-flight deduplication, and caching tests.
//

import Testing
import Foundation
#if canImport(AppKit)
import AppKit
#endif
@testable import MSRU

@Suite("Artwork Loader Tests")
struct ArtworkLoaderTests {

    private func createTestImageData() -> Data {
        #if canImport(AppKit)
        let size = NSSize(width: 200, height: 200)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            return Data()
        }
        return png
        #else
        return Data()
        #endif
    }

    @Test("ArtworkLoader returns nil for non-existent reference")
    func testNonExistentReference() async {
        let loader = ArtworkLoader(maxMemoryBytes: 1024 * 1024, maxCount: 10)
        let thumb = await loader.loadThumbnail(for: "non-existent-hash-key")
        #expect(thumb == nil)

        let emptyThumb = await loader.loadThumbnail(for: "")
        #expect(emptyThumb == nil)
    }

    @Test("ArtworkLoader loads thumbnail and caches downsampled result")
    func testLoadThumbnailAndCache() async throws {
        let imageData = createTestImageData()
        guard !imageData.isEmpty else { return }

        // Store into LocalArtworkStorage
        guard let ref = LocalArtworkStorage.shared.storeArtwork(imageData) else {
            Issue.record("Failed to store test image in LocalArtworkStorage")
            return
        }

        let loader = ArtworkLoader(maxMemoryBytes: 10 * 1024 * 1024, maxCount: 50)

        // First load generates thumbnail
        let thumb1 = await loader.loadThumbnail(for: ref, targetSize: CGSize(width: 80, height: 80))
        #expect(thumb1 != nil)

        // Second load hits cache
        let thumb2 = await loader.loadThumbnail(for: ref, targetSize: CGSize(width: 80, height: 80))
        #expect(thumb2 != nil)
        #expect(thumb1 === thumb2)

        // Full resolution load
        let full = await loader.loadFullImage(for: ref)
        #expect(full != nil)

        // Clear cache
        await loader.clearCache()
    }

    @Test("ArtworkLoader deduplicates in-flight tasks for concurrent requests")
    func testInFlightDeduplication() async throws {
        let imageData = createTestImageData()
        guard !imageData.isEmpty else { return }

        guard let ref = LocalArtworkStorage.shared.storeArtwork(imageData) else {
            Issue.record("Failed to store test image in LocalArtworkStorage")
            return
        }

        let loader = ArtworkLoader(maxMemoryBytes: 10 * 1024 * 1024, maxCount: 50)

        async let req1 = loader.loadThumbnail(for: ref, targetSize: CGSize(width: 64, height: 64))
        async let req2 = loader.loadThumbnail(for: ref, targetSize: CGSize(width: 64, height: 64))

        let (t1, t2) = await (req1, req2)
        #expect(t1 != nil)
        #expect(t2 != nil)
        #expect(t1 === t2)
    }

    @Test("Verify PixelBucket dimension values")
    func testPixelBucketDimensions() {
        #expect(PixelBucket.pt32.maxPixelDimension == 64)
        #expect(PixelBucket.pt64.maxPixelDimension == 128)
        #expect(PixelBucket.pt128.maxPixelDimension == 256)
        #expect(PixelBucket.pt256.maxPixelDimension == 512)
        #expect(PixelBucket.original.maxPixelDimension == 0)
    }

    @Test("Verify ArtworkLoader instance initialization and prefetch non-crashing")
    func testArtworkLoaderPrefetch() async {
        let loader = ArtworkLoader()
        // Prefetch with non-existent references should safely no-op without error or crash
        await loader.prefetch(references: ["non_existent_artwork_1.jpg", "non_existent_2.jpg"], bucket: .pt64)
        let result = await loader.loadThumbnail(for: "non_existent.jpg", bucket: .pt64)
        #expect(result == nil)
    }
}

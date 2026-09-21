//
//  ArtworkLoaderV2Tests.swift
//  MSRUTests
//
//  Unit tests verifying 3-Tier Artwork Pipeline (L1 memory, L2 disk, L3 store) and pixel bucket keys.
//

import Testing
import Foundation
#if canImport(AppKit)
import AppKit
#endif
@testable import MSRU

@Suite("ArtworkLoaderV2 Tests")
struct ArtworkLoaderV2Tests {

    @Test("Verify PixelBucket dimension values")
    func testPixelBucketDimensions() {
        #expect(PixelBucket.pt32.maxPixelDimension == 64)
        #expect(PixelBucket.pt64.maxPixelDimension == 128)
        #expect(PixelBucket.pt128.maxPixelDimension == 256)
        #expect(PixelBucket.pt256.maxPixelDimension == 512)
        #expect(PixelBucket.original.maxPixelDimension == 0)
    }

    @Test("Verify ArtworkLoaderV2 instance initialization and prefetch non-crashing")
    func testArtworkLoaderPrefetch() async {
        let loader = ArtworkLoaderV2()
        // Prefetch with non-existent references should safely no-op without error or crash
        await loader.prefetch(references: ["non_existent_artwork_1.jpg", "non_existent_2.jpg"], bucket: .pt64)
        let result = await loader.loadThumbnail(for: "non_existent.jpg", bucket: .pt64)
        #expect(result == nil)
    }
}

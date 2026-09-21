//
//  CustomAudioCodecTests.swift
//  MSRUTests
//

import Foundation
import Testing
@testable import MSRU
import MSRUCodecFFmpeg

@MainActor
@Suite("Custom Audio Codec Architecture Tests")
struct CustomAudioCodecTests {

    @Test("ExtendedAudioFormatSupport recognizes DTS, APE, and DSD (DSF/DFF)")
    func testExtendedAudioFormatSupportRecognizesAllTargetFormats() {
        let supportedExtensions = ["dts", "dtshd", "ape", "dsf", "dff", "DTS", "APE", "DSF", "DFF"]
        for ext in supportedExtensions {
            let url = URL(fileURLWithPath: "/music/track.\(ext)")
            #expect(ExtendedAudioFormatSupport.supports(url), "Expected format .\(ext) to be supported by ExtendedAudioFormatSupport")
        }

        let nativeAppleExtensions = ["flac", "mp3", "m4a", "wav", "aac", "aiff", "alac"]
        for ext in nativeAppleExtensions {
            let url = URL(fileURLWithPath: "/music/track.\(ext)")
            #expect(!ExtendedAudioFormatSupport.supports(url), "Format .\(ext) should be handled natively by Apple CoreAudio, not extended provider")
        }
    }

    @Test("LocalPlaybackProvider diverts extended formats away from native AVPlayer")
    func testLocalPlaybackProviderRejectsExtendedFormats() {
        let provider = LocalPlaybackProvider()
        let extendedFiles = [
            URL(fileURLWithPath: "/music/sample.dts"),
            URL(fileURLWithPath: "/music/album.ape"),
            URL(fileURLWithPath: "/music/track.dsf"),
            URL(fileURLWithPath: "/music/audio.dff")
        ]

        for url in extendedFiles {
            let request = PlaybackRequest(itemID: "track-1", source: .local, localFileURL: url)
            #expect(!provider.canResolve(request), "LocalPlaybackProvider must reject \(url.lastPathComponent) to allow ExtendedAudioPlaybackProvider resolution")
        }

        let standardFiles = [
            URL(fileURLWithPath: "/music/track.flac"),
            URL(fileURLWithPath: "/music/song.mp3"),
            URL(fileURLWithPath: "/music/audio.wav")
        ]

        for url in standardFiles {
            let request = PlaybackRequest(itemID: "track-2", source: .local, localFileURL: url)
            #expect(provider.canResolve(request), "LocalPlaybackProvider should resolve standard native format: \(url.lastPathComponent)")
        }
    }

    @Test("ExtendedAudioPlaybackProvider can resolve all extended audiophile formats")
    func testExtendedAudioPlaybackProviderCanResolve() {
        let provider = ExtendedAudioPlaybackProvider()
        let targetURLs = [
            URL(fileURLWithPath: "/Volumes/Music/multichannel.dts"),
            URL(fileURLWithPath: "/Volumes/Music/rip.ape"),
            URL(fileURLWithPath: "/Volumes/Music/sacd.dsf"),
            URL(fileURLWithPath: "/Volumes/Music/dsdiff.dff")
        ]

        for url in targetURLs {
            let request = PlaybackRequest(itemID: "track-3", source: .local, localFileURL: url)
            #expect(provider.canResolve(request), "ExtendedAudioPlaybackProvider must resolve \(url.lastPathComponent)")
        }
    }

    @Test("Multichannel PCMFrameBlock preserves 5.1 surround channel layout")
    func testMultichannelPCMFrameBlockPreservesLayout() {
        let frameCount = 1024
        // 5.1 surround: L, R, C, LFE, Ls, Rs
        let channelCount = 6
        let channels: [[Float]] = (0..<channelCount).map { chIndex in
            [Float](repeating: Float(chIndex + 1) * 0.1, count: frameCount)
        }

        let block = PCMFrameBlock(channels: channels, frameCount: frameCount)

        #expect(block.frameCount == frameCount)
        #expect(block.channelCount == 6)
        #expect(block.channels.count == 6)
        #expect(block.channels[0].first == 0.1) // Left
        #expect(block.channels[1].first == 0.2) // Right
        #expect(block.channels[2].first == 0.3) // Center
        #expect(block.channels[3].first == 0.4) // LFE / Sub
        #expect(block.channels[4].first == 0.5) // Left Surround
        #expect(block.channels[5].first == 0.6) // Right Surround

        // Backward compatibility computed properties
        #expect(block.left.count == frameCount)
        #expect(block.right.count == frameCount)
        #expect(block.left.first == 0.1)
        #expect(block.right.first == 0.2)
    }

    @Test("PCMStreamFormat carries channel layout mask and format hint")
    func testPCMStreamFormatCarriesChannelLayoutAndFormatHint() {
        let format = PCMStreamFormat(
            sampleRate: 88200,
            channels: 6,
            channelLayoutMask: 0x3F, // 5.1 standard mask
            duration: 245.5,
            bitRate: 5644800,
            canSeek: true,
            formatHint: "DSD_LSBF (dsf)"
        )

        #expect(format.sampleRate == 88200)
        #expect(format.channels == 6)
        #expect(format.channelLayoutMask == 0x3F)
        #expect(format.duration == 245.5)
        #expect(format.canSeek == true)
        #expect(format.formatHint == "DSD_LSBF (dsf)")
    }

    @Test("FFmpeg version string is available from compiled micro framework")
    func testFFmpegVersionAvailable() {
        let version = FFmpegAudioDecoder.ffmpegVersion
        #expect(!version.isEmpty)
        #expect(version != "Unknown")
    }

    @Test("Real DSF file decoding and seeking (DSD-to-PCM decimation)")
    func testDecodeRealDSFFile() throws {
        let dsfURL = URL(fileURLWithPath: "/Volumes/资料盘/70-媒体与收藏/71-音乐库/Artists/华语女/陈慧娴/陈慧娴 - The Wall.dsf")
        guard FileManager.default.fileExists(atPath: dsfURL.path) else {
            print("Skipping testDecodeRealDSFFile: file not found on disk")
            return
        }

        let decoder = try FFmpegAudioDecoder(url: dsfURL)
        #expect(decoder.format.channels == 2)
        #expect(decoder.format.sampleRate == 88200 || decoder.format.sampleRate == 176400)
        #expect(decoder.format.duration ?? 0 > 0)
        #expect(decoder.format.canSeek == true)

        let block = try decoder.read(maxFrames: 4096)
        let firstBlock = try #require(block)
        #expect(firstBlock.frameCount > 0)
        #expect(firstBlock.channels.count == 2)
        #expect(firstBlock.channels[0].count == firstBlock.frameCount)
        #expect(firstBlock.channels[1].count == firstBlock.frameCount)

        // Test seeking to 10.0 seconds
        try decoder.seek(to: 10.0)
        let blockAfterSeek = try decoder.read(maxFrames: 4096)
        let seekBlock = try #require(blockAfterSeek)
        #expect(seekBlock.frameCount > 0)
        decoder.close()
    }

    @Test("Real APE file decoding and seeking (Monkey's Audio)")
    func testDecodeRealAPEFile() throws {
        let apeURL = URL(fileURLWithPath: "/Volumes/资料盘/70-媒体与收藏/71-音乐库/Artists/华语男/李克勤/李克勤-护花使者.ape")
        guard FileManager.default.fileExists(atPath: apeURL.path) else {
            print("Skipping testDecodeRealAPEFile: file not found on disk")
            return
        }

        let decoder = try FFmpegAudioDecoder(url: apeURL)
        #expect(decoder.format.channels == 2)
        #expect(decoder.format.sampleRate == 44100)
        #expect(decoder.format.duration ?? 0 > 0)
        #expect(decoder.format.canSeek == true)

        let block = try decoder.read(maxFrames: 4096)
        let firstBlock = try #require(block)
        #expect(firstBlock.frameCount > 0)
        #expect(firstBlock.channels.count == 2)

        // Test seeking to 5.0 seconds
        try decoder.seek(to: 5.0)
        let blockAfterSeek = try decoder.read(maxFrames: 4096)
        let seekBlock = try #require(blockAfterSeek)
        #expect(seekBlock.frameCount > 0)
        decoder.close()
    }

    @Test("Decoder format is strictly negotiated and locked at open time (P1-1)")
    func testDecoderFormatLockedAtOpen() throws {
        let dsfURL = URL(fileURLWithPath: "/Volumes/资料盘/70-媒体与收藏/71-音乐库/Artists/华语女/陈慧娴/陈慧娴 - The Wall.dsf")
        guard FileManager.default.fileExists(atPath: dsfURL.path) else { return }

        let decoder = try FFmpegAudioDecoder(url: dsfURL)
        let initialSampleRate = decoder.format.sampleRate
        let initialChannels = decoder.format.channels
        let canSeek = decoder.format.canSeek

        #expect(canSeek == true)
        #expect(initialChannels == 2)
        #expect(initialSampleRate == 88200 || initialSampleRate == 176400)

        // Read several blocks
        for _ in 0..<5 {
            let block = try decoder.read(maxFrames: 2048)
            let validBlock = try #require(block)
            #expect(validBlock.channelCount == initialChannels)
            #expect(validBlock.frameCount > 0)
        }

        // Verify format remained exactly identical
        #expect(decoder.format.sampleRate == initialSampleRate)
        #expect(decoder.format.channels == initialChannels)
        decoder.close()
    }

    @Test("Repeated seek cycles cleanly reset resampler and state machine (P1-2)")
    func testRepeatedSeekCyclesCleanReset() throws {
        let apeURL = URL(fileURLWithPath: "/Volumes/资料盘/70-媒体与收藏/71-音乐库/Artists/华语男/李克勤/李克勤-护花使者.ape")
        guard FileManager.default.fileExists(atPath: apeURL.path) else { return }

        let decoder = try FFmpegAudioDecoder(url: apeURL)
        let seekTargets: [TimeInterval] = [10.0, 2.0, 25.0, 0.0, 15.0]

        for target in seekTargets {
            try decoder.seek(to: target)
            let block = try decoder.read(maxFrames: 2048)
            let b = try #require(block)
            #expect(b.frameCount > 0)
            #expect(b.channelCount == 2)
        }

        decoder.close()
    }

    @Test("Decoder thread-safety under concurrent access (P1-5)")
    func testDecoderThreadSafetyConcurrentAccess() throws {
        let apeURL = URL(fileURLWithPath: "/Volumes/资料盘/70-媒体与收藏/71-音乐库/Artists/华语男/李克勤/李克勤-护花使者.ape")
        guard FileManager.default.fileExists(atPath: apeURL.path) else { return }

        let decoder = try FFmpegAudioDecoder(url: apeURL)
        let group = DispatchGroup()

        // Concurrent reads and seeks
        for i in 0..<8 {
            group.enter()
            DispatchQueue.global().async {
                do {
                    if i % 2 == 0 {
                        try decoder.seek(to: Double(i * 3))
                    }
                    _ = try decoder.read(maxFrames: 1024)
                } catch {
                    // Ignore closed or expected errors during concurrent stress
                }
                group.leave()
            }
        }

        group.wait()
        decoder.close()
    }
}

//
//  Fixtures.swift
//  MSRUTests
//
//  Deterministic in-memory entity builders and minimal audio fixture generators.
//

import Foundation
import AppFoundation
@testable import MSRU

enum Fixtures {

    // MARK: - Audio File Generator

    /// Generates a valid, deterministic PCM WAV audio file with standard RIFF header in a temporary location.
    /// AVFoundation and Chromaprint can parse and decode this file without errors.
    static func createDeterministicWAV(
        durationSeconds: Double = 1.0,
        sampleRate: Int = 44100,
        channels: Int = 1,
        frequencyHz: Double = 440.0
    ) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let fileURL = tempDir.appendingPathComponent("fixture_\(Int(durationSeconds * 1000))ms.wav")

        let totalSamples = Int(Double(sampleRate) * durationSeconds)
        let bytesPerSample = 2 // 16-bit
        let dataSize = totalSamples * channels * bytesPerSample

        var data = Data()

        // RIFF Header
        data.append(contentsOf: "RIFF".utf8)
        let fileSize32 = UInt32(36 + dataSize)
        var fileSizeLE = fileSize32.littleEndian
        data.append(Data(bytes: &fileSizeLE, count: 4))
        data.append(contentsOf: "WAVE".utf8)

        // "fmt " Subchunk
        data.append(contentsOf: "fmt ".utf8)
        var subchunk1Size = UInt32(16).littleEndian
        data.append(Data(bytes: &subchunk1Size, count: 4))
        var audioFormat = UInt16(1).littleEndian // PCM
        data.append(Data(bytes: &audioFormat, count: 2))
        var numChannels16 = UInt16(channels).littleEndian
        data.append(Data(bytes: &numChannels16, count: 2))
        var sampleRate32 = UInt32(sampleRate).littleEndian
        data.append(Data(bytes: &sampleRate32, count: 4))
        let byteRate = UInt32(sampleRate * channels * bytesPerSample)
        var byteRate32 = byteRate.littleEndian
        data.append(Data(bytes: &byteRate32, count: 4))
        var blockAlign16 = UInt16(channels * bytesPerSample).littleEndian
        data.append(Data(bytes: &blockAlign16, count: 2))
        var bitsPerSample16 = UInt16(16).littleEndian
        data.append(Data(bytes: &bitsPerSample16, count: 2))

        // "data" Subchunk
        data.append(contentsOf: "data".utf8)
        var dataSize32 = UInt32(dataSize).littleEndian
        data.append(Data(bytes: &dataSize32, count: 4))

        // Deterministic PCM 16-bit sine wave data
        for i in 0..<totalSamples {
            let t = Double(i) / Double(sampleRate)
            let sampleVal = sin(2.0 * .pi * frequencyHz * t)
            let intSample = Int16(max(-32767, min(32767, sampleVal * 20000.0)))
            var leSample = intSample.littleEndian
            for _ in 0..<channels {
                data.append(Data(bytes: &leSample, count: 2))
            }
        }

        try data.write(to: fileURL)
        return fileURL
    }

    // MARK: - Domain Builders

    static func makeArtist(
        id: String = "art_test_jay",
        canonicalName: String = "周杰伦",
        aliases: [EntityAlias] = [EntityAlias(name: "Jay Chou", localeIdentifier: "en")]
    ) -> ArtistEntity {
        ArtistEntity(id: id, canonicalName: canonicalName, aliases: aliases)
    }

    static func makeWork(
        id: String = "wrk_test_sunny",
        title: String = "晴天",
        type: WorkType = .song
    ) -> Work {
        Work(id: id, title: title, workType: type)
    }

    static func makeRecording(
        id: String = "rec_test_sunny",
        title: String = "晴天",
        artistName: String = "周杰伦",
        workID: String? = "wrk_test_sunny",
        duration: TimeInterval = 269.0,
        isLive: Bool = false
    ) -> Recording {
        let artist = makeArtist(canonicalName: artistName)
        return Recording(
            id: id,
            title: title,
            artistCredit: ArtistCredit(single: artist),
            workID: workID,
            duration: duration,
            isLive: isLive
        )
    }

    static func makeReleaseGroup(
        id: String = "rg_test_ye_hui_mei",
        title: String = "叶惠美",
        artistName: String = "周杰伦"
    ) -> ReleaseGroup {
        let artist = makeArtist(canonicalName: artistName)
        return ReleaseGroup(
            id: id,
            title: title,
            artistCredit: ArtistCredit(single: artist),
            primaryType: .album
        )
    }

    static func makeRelease(
        id: String = "rel_test_ye_hui_mei_tw",
        releaseGroupID: String = "rg_test_ye_hui_mei",
        title: String = "叶惠美",
        artistName: String = "周杰伦",
        date: String = "2003-07-31",
        country: String = "TW",
        tracks: [MusicTrack] = []
    ) -> Release {
        let artist = makeArtist(canonicalName: artistName)
        let medium = Medium(position: 1, format: "CD", tracks: tracks)
        return Release(
            id: id,
            releaseGroupID: releaseGroupID,
            title: title,
            artistCredit: ArtistCredit(single: artist),
            date: date,
            country: country,
            media: [medium]
        )
    }

    static func makeAudioAsset(
        id: String = UUID().uuidString,
        fileURL: URL = URL(fileURLWithPath: "/music/sunny.flac"),
        fileSize: Int64 = 30_000_000,
        format: String = "FLAC",
        bitDepth: String = "24-bit",
        sampleRate: Double = 96000,
        duration: TimeInterval = 269.0,
        recordingID: String? = nil
    ) -> AudioAsset {
        AudioAsset(
            id: id,
            fileURL: fileURL,
            fileSize: fileSize,
            format: format,
            bitDepth: bitDepth,
            sampleRate: sampleRate,
            duration: duration,
            recordingID: recordingID
        )
    }
}

import Foundation
import Testing
import GRDB
@testable import MusicLibrary
@testable import MusicDomain

@Suite("Audio Tagging & Identity Tests")
struct AudioTaggingAndIdentityTests {

    @Test("AudioStandardTags initializer and default values")
    func testAudioStandardTags() {
        let tags = AudioStandardTags(
            title: "Song Title",
            artist: "Artist Name",
            album: "Album Name",
            trackNumber: 3,
            totalTracks: 12,
            year: 2024,
            genre: "Hi-Res Classical"
        )

        #expect(tags.title == "Song Title")
        #expect(tags.artist == "Artist Name")
        #expect(tags.album == "Album Name")
        #expect(tags.trackNumber == 3)
        #expect(tags.totalTracks == 12)
        #expect(tags.year == 2024)
        #expect(tags.genre == "Hi-Res Classical")
    }

    @Test("AudioTechnicalSpecs formatting helpers")
    func testAudioTechnicalSpecsFormatting() {
        let hires = AudioTechnicalSpecs(
            formatName: "FLAC Lossless Audio",
            sampleRate: 96000,
            bitDepth: 24,
            channelCount: 2,
            duration: 215.5,
            fileSize: 52_428_800,
            bitrate: 1945
        )

        #expect(hires.formattedSampleRate == "96.0 kHz")
        #expect(hires.formattedBitDepth == "24-bit")
        #expect(hires.channelLayoutDescription == "Stereo (2.0)")
        #expect(hires.formattedDuration == "3:35")
        #expect(hires.formattedBitrate == "1945 kbps")

        let multichannel = AudioTechnicalSpecs(
            formatName: "Waveform Audio (WAV)",
            sampleRate: 44100,
            bitDepth: 16,
            channelCount: 6,
            duration: 60,
            fileSize: 10_000_000
        )

        #expect(multichannel.formattedSampleRate == "44.1 kHz")
        #expect(multichannel.channelLayoutDescription == "5.1 Surround")
    }

    @Test("AudioTagWriter builds valid ID3v2.4 frame headers")
    func testAudioTagWriterID3v2Generation() {
        let writer = AudioTagWriter()
        let tags = AudioStandardTags(
            title: "Test Track",
            artist: "Test Artist",
            album: "Test Album",
            trackNumber: 1,
            totalTracks: 10,
            year: 2024,
            genre: "Jazz"
        )

        let id3Data = writer.buildID3v2Tag(tags: tags)
        #expect(id3Data.count > 10)
        // ID3 header check: "ID3"
        #expect(id3Data[0] == 0x49) // 'I'
        #expect(id3Data[1] == 0x44) // 'D'
        #expect(id3Data[2] == 0x33) // '3'
        #expect(id3Data[3] == 0x04) // ID3v2.4
    }

    @Test("AssetRepository moveAsset renames path while keeping asset record and recordingID")
    func testAssetRepositoryMove() throws {
        let appDb = try AppDatabase.makeEphemeral()
        let sourceID = SourceID("src_local_default")
        let recordingID = RecordingID("rec_test_stable_123")
        let assetID = AssetID("ast_1")

        try appDb.dbWriter.write { db in
            try db.execute(
                sql: "INSERT INTO sources (id, source_type, uri, display_name, capabilities, is_enabled, created_at, updated_at) VALUES (?, 'local', 'file:///', 'Local', 1, 1, ?, ?)",
                arguments: [sourceID.rawValue, Date(), Date()]
            )

            try db.execute(
                sql: "INSERT INTO recordings (id, title, sort_title, created_at) VALUES (?, 'Song', 'Song', ?)",
                arguments: [recordingID.rawValue, Date()]
            )

            let asset = PersistedAssetRecord(
                id: assetID,
                sourceID: sourceID,
                relativePath: "Music/OldArtist/Song.flac",
                fileSize: 1024,
                mtime: 1000,
                format: "flac",
                duration: 180,
                recordingID: recordingID
            )
            try AssetRepository.batchUpsert([asset], in: db)

            // Verify before move
            let before = try AssetRepository.existingAssetBindings(
                forSourceID: sourceID,
                relativePaths: ["Music/OldArtist/Song.flac"],
                in: db
            )
            #expect(before["Music/OldArtist/Song.flac"]?.assetID == assetID)
            #expect(before["Music/OldArtist/Song.flac"]?.recordingID == recordingID)

            // Perform move
            try AssetRepository.moveAsset(
                from: "Music/OldArtist/Song.flac",
                to: "Music/NewArtist/Song.flac",
                sourceID: sourceID,
                in: db
            )

            // Verify after move: old path no longer exists
            let oldLookup = try AssetRepository.existingAssetBindings(
                forSourceID: sourceID,
                relativePaths: ["Music/OldArtist/Song.flac"],
                in: db
            )
            #expect(oldLookup["Music/OldArtist/Song.flac"] == nil)

            // Verify after move: new path has preserved assetID and recordingID!
            let newLookup = try AssetRepository.existingAssetBindings(
                forSourceID: sourceID,
                relativePaths: ["Music/NewArtist/Song.flac"],
                in: db
            )
            #expect(newLookup["Music/NewArtist/Song.flac"]?.assetID == assetID)
            #expect(newLookup["Music/NewArtist/Song.flac"]?.recordingID == recordingID)
        }
    }
}

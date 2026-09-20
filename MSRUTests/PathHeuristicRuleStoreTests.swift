//
//  PathHeuristicRuleStoreTests.swift
//  MSRUTests
//
//  Created for Directory Path Heuristics & Local Rule Learning testing.
//

import Testing
import Foundation
@testable import MSRU

@MainActor
struct PathHeuristicRuleStoreTests {

    @Test
    func addRuleAndMatchFilePath() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storageURL = tempDir.appendingPathComponent("test_rules.json")
        let store = PathHeuristicRuleStore(storageURL: storageURL)

        #expect(store.rules.isEmpty)

        // Add rule
        store.addRule(pathPattern: "王力宏", targetArtist: "王力宏", targetAlbum: "唯一")
        #expect(store.rules.count == 1)

        // Matching file path with "王力宏"
        let hitURL = URL(fileURLWithPath: "/Volumes/NAS/03 音乐资源/音乐/1.歌曲/男歌手/王力宏/01. 唯一.flac")
        let matched = store.match(fileURL: hitURL)
        #expect(matched != nil)
        #expect(matched?.targetArtist == "王力宏")
        #expect(matched?.targetAlbum == "唯一")
        #expect(store.rules.first?.matchCount == 1)

        // Non-matching file path
        let missURL = URL(fileURLWithPath: "/Volumes/NAS/03 音乐资源/音乐/1.歌曲/女歌手/王菲/01. 红豆.flac")
        let missed = store.match(fileURL: missURL)
        #expect(missed == nil)
    }

    @Test
    func learnFromFolderURL() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storageURL = tempDir.appendingPathComponent("test_rules.json")
        let store = PathHeuristicRuleStore(storageURL: storageURL)

        let folderURL = URL(fileURLWithPath: "/Volumes/NAS/音乐/1.歌曲/男歌手/周杰伦")
        store.learnFrom(folderURL: folderURL, artist: "周杰伦", album: "范特西")

        #expect(store.rules.count == 1)
        #expect(store.rules.first?.pathPattern == "周杰伦")
        #expect(store.rules.first?.targetArtist == "周杰伦")

        let trackURL = URL(fileURLWithPath: "/Users/ciro/Music/周杰伦/01. 爱在公元前.mp3")
        let match = store.match(fileURL: trackURL)
        #expect(match != nil)
        #expect(match?.targetArtist == "周杰伦")
        #expect(match?.targetAlbum == "范特西")
    }

    @Test
    func removeAndPersistence() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storageURL = tempDir.appendingPathComponent("test_rules.json")
        let store = PathHeuristicRuleStore(storageURL: storageURL)

        store.addRule(pathPattern: "陶喆", targetArtist: "陶喆")
        store.addRule(pathPattern: "陈奕迅", targetArtist: "陈奕迅")
        #expect(store.rules.count == 2)

        // Reopen store from disk
        let reopened = PathHeuristicRuleStore(storageURL: storageURL)
        #expect(reopened.rules.count == 2)

        // Remove by ID
        if let first = reopened.rules.first {
            reopened.removeRule(id: first.id)
            #expect(reopened.rules.count == 1)
        }

        // Remove all
        reopened.removeAll()
        #expect(reopened.rules.isEmpty)

        // Verify disk is cleared
        let emptyStore = PathHeuristicRuleStore(storageURL: storageURL)
        #expect(emptyStore.rules.isEmpty)
    }

    @Test
    func rejectUnknownArtistAndAutoRepair() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storageURL = tempDir.appendingPathComponent("test_rules.json")
        let store = PathHeuristicRuleStore(storageURL: storageURL)

        // 1. Direct attempt to add "Unknown Artist" should be rejected
        store.addRule(pathPattern: "SomeFolder", targetArtist: "Unknown Artist")
        #expect(store.rules.isEmpty)

        // 2. Learning from a folder named "刘达 - 甄选2024(24K金碟头版限量)" with "Unknown Artist"
        // should automatically extract artist and album
        let folderURL = URL(fileURLWithPath: "/Music/刘达 - 甄选2024(24K金碟头版限量)")
        store.learnFrom(folderURL: folderURL, artist: "Unknown Artist", album: nil)

        #expect(store.rules.count == 1)
        let rule = store.rules.first
        #expect(rule?.pathPattern == "刘达 - 甄选2024(24K金碟头版限量)")
        #expect(rule?.targetArtist == "刘达")
        #expect(rule?.targetAlbum == "甄选2024(24K金碟头版限量)")

        // 3. Auto-repair on load for old corrupted files with "Unknown Artist"
        let rawCorrupted = """
        [
            {
                "id": "11111111-2222-3333-4444-555555555555",
                "pathPattern": "林俊杰 - 编号89757",
                "targetArtist": "Unknown Artist",
                "matchCount": 0,
                "dateAdded": 700000000
            },
            {
                "id": "22222222-3333-4444-5555-666666666666",
                "pathPattern": "UnsalvageableFolder",
                "targetArtist": "Unknown Artist",
                "matchCount": 0,
                "dateAdded": 700000000
            }
        ]
        """.data(using: .utf8)!
        try rawCorrupted.write(to: storageURL)

        let reloadedStore = PathHeuristicRuleStore(storageURL: storageURL)
        // The un-salvageable rule should be dropped, the one with "Artist - Album" should be repaired!
        #expect(reloadedStore.rules.count == 1)
        #expect(reloadedStore.rules.first?.targetArtist == "林俊杰")
        #expect(reloadedStore.rules.first?.targetAlbum == "编号89757")
    }
}

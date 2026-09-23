//
//  SmartPlaylistTests.swift
//  MSRUTests
//
//  Unit tests covering smart playlist rule evaluation engine, presets,
//  dynamic track resolution, and SQLite persistence round-trips.
//

import Testing
import Foundation
import AppFoundation
import MusicDomain
@testable import MSRU

@MainActor
@Suite("Smart Playlist Engine & Persistence Contracts")
struct SmartPlaylistTests {

    private func makeSampleContexts() -> [TrackEvaluationContext] {
        let now = Date()
        let fiveDaysAgo = Calendar.current.date(byAdding: .day, value: -5, to: now)!
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now)!

        return [
            TrackEvaluationContext(
                id: "track_hires_flac",
                title: "Ode to Joy (Hi-Res)",
                artist: "Ludwig van Beethoven",
                album: "Symphony No. 9",
                genre: "Classical",
                isFavorite: true,
                isLossless: true,
                isHiRes: true,
                sampleRate: 96000,
                bitDepth: 24,
                year: 1824,
                addedAt: fiveDaysAgo,
                playCount: 15,
                duration: 420
            ),
            TrackEvaluationContext(
                id: "track_lossless_alac",
                title: "Nocturne Op. 9 No. 2",
                artist: "Frédéric Chopin",
                album: "Complete Nocturnes",
                genre: "Classical",
                isFavorite: false,
                isLossless: true,
                isHiRes: false,
                sampleRate: 44100,
                bitDepth: 16,
                year: 1832,
                addedAt: thirtyDaysAgo,
                playCount: 42,
                duration: 270
            ),
            TrackEvaluationContext(
                id: "track_lossy_mp3",
                title: "Pop Anthem 2024",
                artist: "Modern Pop Star",
                album: "Summer Hits",
                genre: "Pop",
                isFavorite: true,
                isLossless: false,
                isHiRes: false,
                sampleRate: 44100,
                bitDepth: 16,
                year: 2024,
                addedAt: now,
                playCount: 100,
                duration: 195
            ),
            TrackEvaluationContext(
                id: "track_rock_dsd",
                title: "Classic Rock Anthem",
                artist: "The Vintage Band",
                album: "Vintage Masters",
                genre: "Rock",
                isFavorite: false,
                isLossless: true,
                isHiRes: true,
                sampleRate: 2822400,
                bitDepth: 1,
                year: 1975,
                addedAt: now,
                playCount: 5,
                duration: 310
            )
        ]
    }

    // MARK: - Rule Evaluation Tests

    @Test
    func ruleEngineFiltersByStringField() {
        let contexts = makeSampleContexts()

        let rule = SmartPlaylistRule(
            field: .artist,
            op: .contains,
            value: .string("Chopin")
        )
        let group = SmartPlaylistRuleGroup(matchMode: .all, rules: [rule])

        let result = PlaylistRuleEngine.evaluate(
            rules: group,
            tracks: contexts
        )

        #expect(result.count == 1)
        #expect(result.first?.id == "track_lossless_alac")
    }

    @Test
    func ruleEngineFiltersByFavoriteStatus() {
        let contexts = makeSampleContexts()

        let rule = SmartPlaylistRule(
            field: .isFavorite,
            op: .isTrue,
            value: .boolean(true)
        )
        let group = SmartPlaylistRuleGroup(matchMode: .all, rules: [rule])

        let result = PlaylistRuleEngine.evaluate(
            rules: group,
            tracks: contexts
        )

        #expect(result.count == 2)
        let ids = Set(result.map(\.id))
        #expect(ids == ["track_hires_flac", "track_lossy_mp3"])
    }

    @Test
    func ruleEngineFiltersByHiResAudio() {
        let contexts = makeSampleContexts()

        let rule = SmartPlaylistRule(
            field: .isHiRes,
            op: .isTrue,
            value: .boolean(true)
        )
        let group = SmartPlaylistRuleGroup(matchMode: .all, rules: [rule])

        let result = PlaylistRuleEngine.evaluate(
            rules: group,
            tracks: contexts
        )

        #expect(result.count == 2)
        let ids = Set(result.map(\.id))
        #expect(ids.contains("track_hires_flac"))
        #expect(ids.contains("track_rock_dsd"))
    }

    @Test
    func ruleEngineCompoundMatchModeAny() {
        let contexts = makeSampleContexts()

        let genrePopRule = SmartPlaylistRule(
            field: .genre,
            op: .equals,
            value: .string("Pop")
        )
        let genreRockRule = SmartPlaylistRule(
            field: .genre,
            op: .equals,
            value: .string("Rock")
        )
        let group = SmartPlaylistRuleGroup(
            matchMode: .any,
            rules: [genrePopRule, genreRockRule]
        )

        let result = PlaylistRuleEngine.evaluate(
            rules: group,
            tracks: contexts
        )

        #expect(result.count == 2)
        let genres = Set(result.map(\.genre))
        #expect(genres == ["Pop", "Rock"])
    }

    @Test
    func ruleEngineFiltersByDateAddedInLastNDays() {
        let contexts = makeSampleContexts()

        // 7 days window includes fiveDaysAgo and now, but excludes thirtyDaysAgo
        let rule = SmartPlaylistRule(
            field: .addedAt,
            op: .inLastNDays,
            value: .days(7)
        )
        let group = SmartPlaylistRuleGroup(matchMode: .all, rules: [rule])

        let result = PlaylistRuleEngine.evaluate(
            rules: group,
            tracks: contexts
        )

        #expect(result.count == 3)
        #expect(!result.contains { $0.id == "track_lossless_alac" })
    }

    @Test
    func ruleEngineSortsAndLimitsResults() {
        let contexts = makeSampleContexts()

        let group = SmartPlaylistRuleGroup(
            matchMode: .all,
            rules: [],
            limit: 2,
            sortBy: .playCountDescending
        )

        let result = PlaylistRuleEngine.evaluate(
            rules: group,
            tracks: contexts
        )

        #expect(result.count == 2)
        #expect(result[0].playCount == 100)
        #expect(result[1].playCount == 42)
    }

    // MARK: - Presets Tests

    @Test
    func presetsGenerateValidRules() {
        let favoritesPreset = PlaylistRuleEngine.Presets.favorites()
        #expect(favoritesPreset.rules.first?.field == .isFavorite)

        let hiResPreset = PlaylistRuleEngine.Presets.hiResAudio()
        #expect(hiResPreset.rules.first?.field == .isHiRes)

        let losslessPreset = PlaylistRuleEngine.Presets.losslessMasters()
        #expect(losslessPreset.rules.first?.field == .isLossless)

        let recentPreset = PlaylistRuleEngine.Presets.recentlyAdded(days: 14)
        #expect(recentPreset.rules.first?.field == .addedAt)
        #expect(recentPreset.rules.first?.value == .days(14))
    }

    // MARK: - LocalTrack & Store Tests

    @Test
    func localTrackRuleEvaluation() {
        let tracks = [
            LocalTrack(
                fileURL: URL(fileURLWithPath: "/music/beethoven.flac"),
                title: "Symphony No. 5",
                artist: "Beethoven",
                album: "Classical Legends",
                duration: 480,
                year: 1808
            ),
            LocalTrack(
                fileURL: URL(fileURLWithPath: "/music/pop.mp3"),
                title: "Dance Song",
                artist: "Pop Singer",
                album: "Top Hits",
                duration: 180,
                year: 2023
            )
        ]

        let rule = SmartPlaylistRule(
            field: .isLossless,
            op: .isTrue,
            value: .boolean(true)
        )
        let group = SmartPlaylistRuleGroup(matchMode: .all, rules: [rule])

        let result = PlaylistRuleEngine.evaluate(
            rules: group,
            tracks: tracks,
            favorites: []
        )

        #expect(result.count == 1)
        #expect(result.first?.title == "Symphony No. 5")
    }

    @Test
    func playlistStoreCreatesSmartPlaylistAndResolvesTracks() async {
        let repo = PreviewPlaylistRepository(playlists: [])
        let store = PlaylistStore(repository: repo)
        await store.load()

        let tracks = [
            LocalTrack(
                fileURL: URL(fileURLWithPath: "/music/fav.flac"),
                title: "Favorite Song",
                artist: "Great Artist",
                duration: 210
            ),
            LocalTrack(
                fileURL: URL(fileURLWithPath: "/music/other.mp3"),
                title: "Other Song",
                artist: "Other Artist",
                duration: 180
            )
        ]
        let favorites: Set<String> = [tracks[0].id]

        let rules = SmartPlaylistRuleGroup(
            matchMode: .all,
            rules: [
                SmartPlaylistRule(
                    field: .isFavorite,
                    op: .isTrue,
                    value: .boolean(true)
                )
            ]
        )

        let smartPlaylist = await store.createSmartPlaylist(
            title: "Dynamic Favorites",
            description: "Smart collection of favorite tracks",
            rules: rules,
            isPinned: true
        )

        #expect(smartPlaylist.isSmart == true)
        #expect(smartPlaylist.rules != nil)

        // Resolve tracks dynamically
        let resolved = store.resolveTracks(for: smartPlaylist, from: tracks, favorites: favorites)
        #expect(resolved.count == 1)
        #expect(resolved.first?.id == tracks[0].id)
    }

    @Test
    func sqlitePlaylistRepositorySmartPlaylistRoundTrip() async throws {
        let db = try TestDatabase.makeEphemeral()
        let rules = SmartPlaylistRuleGroup(
            matchMode: .all,
            rules: [
                SmartPlaylistRule(
                    field: .sampleRate,
                    op: .greaterThan,
                    value: .number(48000)
                )
            ],
            limit: 50,
            sortBy: .dateAddedDescending
        )

        let smartPlaylist = Playlist(
            title: "Hi-Res Master Collection",
            description: "All studio quality hi-res tracks",
            rules: rules
        )

        let normalPlaylist = Playlist(
            title: "Standard Playlist",
            trackIDs: ["trk_1", "trk_2"]
        )

        let repo1 = SQLitePlaylistRepository(db: db)
        try await repo1.savePlaylists([smartPlaylist, normalPlaylist])

        let repo2 = SQLitePlaylistRepository(db: db)
        let loaded = try await repo2.loadPlaylists()

        #expect(loaded.count == 2)
        let loadedSmart = try #require(loaded.first { $0.title == "Hi-Res Master Collection" })
        #expect(loadedSmart.isSmart == true)
        #expect(loadedSmart.rules != nil)
        #expect(loadedSmart.rules?.sortBy == .dateAddedDescending)
        #expect(loadedSmart.rules?.limit == 50)
        #expect(loadedSmart.rules?.rules.first?.field == .sampleRate)

        let loadedNormal = try #require(loaded.first { $0.title == "Standard Playlist" })
        #expect(loadedNormal.isSmart == false)
        #expect(loadedNormal.rules == nil)
        #expect(loadedNormal.trackIDs == ["trk_1", "trk_2"])
    }

    @Test
    func playlistStoreUpdatesSmartPlaylistTitleDescriptionAndRules() async {
        let repo = PreviewPlaylistRepository(playlists: [])
        let store = PlaylistStore(repository: repo)
        await store.load()

        let initialRules = PlaylistRuleEngine.Presets.recentlyAdded(days: 30)
        let playlist = await store.createSmartPlaylist(
            title: "Old Title",
            description: "Old Desc",
            rules: initialRules
        )

        let newRules = PlaylistRuleEngine.Presets.hiResAudio()
        await store.updatePlaylist(
            id: playlist.id,
            title: "New Title",
            description: "New Desc",
            rules: newRules,
            updateRules: true
        )

        let updated = store.playlist(for: playlist.id)
        #expect(updated?.title == "New Title")
        #expect(updated?.description == "New Desc")
        #expect(updated?.rules?.rules.first?.field == .isHiRes)
    }
}


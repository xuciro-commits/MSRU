//
//  LibraryServices.swift
//  MSRU
//
//  Library services the application owns. Views receive them through
//  `ApplicationModel.services` and never reach for the types' `shared`
//  statics, so previews and tests can run on isolated instances.
//

import Foundation
import MusicLibrary
import MusicPlayback

@MainActor
struct LibraryServices {
    let queries: LibraryQueryEngine
    let fingerprints: LocalFingerprintRegistry
    let acoustID: AcoustIDConfiguration
    let folderRules: PathHeuristicRuleStore
    let biographies: ArtistBiographyService
    let lyrics: LyricsStore
    let lyricsSearch: LyricsService

    /// The live services. Library internals still reach some of these through
    /// `shared`, so live must be those same instances until they are injected
    /// there as well (Docs/WorkQueue.md, convenience globals).
    static func live() -> LibraryServices {
        LibraryServices(
            queries: .shared,
            fingerprints: .shared,
            acoustID: .shared,
            folderRules: .shared,
            biographies: .shared,
            lyrics: .shared,
            lyricsSearch: .shared
        )
    }

    /// Services on an in-memory database, throwaway defaults and a scratch
    /// directory, with no lyrics providers: previews and tests never touch the
    /// user's library, settings or the network through them.
    static func isolated() -> LibraryServices {
        let db = try! AppDatabase.makeEphemeral()
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("msru-isolated-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        return LibraryServices(
            queries: LibraryQueryEngine(db: db),
            fingerprints: LocalFingerprintRegistry(db: db, storageURL: scratch.appendingPathComponent("fingerprints.json")),
            acoustID: AcoustIDConfiguration(defaults: UserDefaults(suiteName: "msru.isolated.\(UUID().uuidString)")!),
            folderRules: PathHeuristicRuleStore(db: db),
            biographies: ArtistBiographyService(cacheDirectory: scratch),
            lyrics: LyricsStore(),
            lyricsSearch: LyricsService(providers: [], cacheDirectory: scratch)
        )
    }
}

import Foundation
import AVFoundation

/// Local media I/O boundary. UI state and selection remain in the store/scene.
protocol LocalLibraryRepository: Sendable {
    func loadTracks() async throws -> [LocalTrack]
    func importTrack(from url: URL) async throws -> LocalTrack?
    func importTracks(from urls: [URL]) async throws -> [LocalTrack]
    func saveTrackInPlace(_ track: LocalTrack) async throws
    func saveTracksInPlace(_ tracks: [LocalTrack]) async throws
    func batchUpsertTracks(_ tracks: [LocalTrack]) async throws
    func deleteTracks(withIDs ids: Set<String>, deletePhysicalFiles: Bool) async throws
    func readTrack(from url: URL) async throws -> LocalTrack
}

extension LocalLibraryRepository {
    func saveTrackInPlace(_ track: LocalTrack) async throws {
        try await saveTracksInPlace([track])
    }
    func saveTracksInPlace(_ tracks: [LocalTrack]) async throws {}
    func batchUpsertTracks(_ tracks: [LocalTrack]) async throws {
        try await saveTracksInPlace(tracks)
    }
    func importTracks(from urls: [URL]) async throws -> [LocalTrack] {
        var imported: [LocalTrack] = []
        for url in urls {
            if let track = try await importTrack(from: url) {
                imported.append(track)
            }
        }
        return imported
    }
    func deleteTracks(withIDs ids: Set<String>, deletePhysicalFiles: Bool) async throws {}
    func readTrack(from url: URL) async throws -> LocalTrack {
        try await SQLiteLocalLibraryRepository.readTrack(from: url)
    }
}

typealias FileLocalLibraryRepository = SQLiteLocalLibraryRepository


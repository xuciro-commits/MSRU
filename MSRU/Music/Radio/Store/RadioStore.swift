//
//  RadioStore.swift
//  MSRU
//

import Foundation
import Observation

@MainActor
@Observable
final class RadioStore {

    private(set) var stations: [RadioStation]
    private(set) var customStations: [RadioStation] = []
    private(set) var favoriteIDs: Set<String> = []
    private(set) var recentStationIDs: [String] = []

    private let persistenceURL: URL?

    init(
        stations: [RadioStation] = RadioStation.defaultStations,
        persistenceURL: URL? = RadioStore.defaultPersistenceURL
    ) {
        self.stations = stations
        self.persistenceURL = persistenceURL
        loadState()
    }

    // MARK: - Computed Projections

    var allStations: [RadioStation] {
        customStations + stations
    }

    var featuredStations: [RadioStation] {
        allStations.filter(\.isFeatured)
    }

    var favoriteStations: [RadioStation] {
        allStations.filter { favoriteIDs.contains($0.id) }
    }

    var recentStations: [RadioStation] {
        recentStationIDs.compactMap { id in
            allStations.first { $0.id == id }
        }
    }

    func isFavorite(id: String) -> Bool {
        favoriteIDs.contains(id)
    }

    func isCustomStation(id: String) -> Bool {
        customStations.contains { $0.id == id }
    }

    // MARK: - Filtering

    func filteredStations(genre: RadioGenre, query: String = "") -> [RadioStation] {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return allStations.filter { station in
            let matchesGenre = (genre == .all) || (station.genre == genre)
            guard matchesGenre else { return false }

            if cleaned.isEmpty {
                return true
            }

            return station.name.lowercased().contains(cleaned)
                || station.description.lowercased().contains(cleaned)
                || station.country.lowercased().contains(cleaned)
                || station.genre.rawValue.lowercased().contains(cleaned)
        }
    }

    // MARK: - Actions

    func toggleFavorite(id: String) {
        if favoriteIDs.contains(id) {
            favoriteIDs.remove(id)
        } else {
            favoriteIDs.insert(id)
        }
        saveState()
    }

    func recordPlayed(station: RadioStation) {
        recentStationIDs.removeAll { $0 == station.id }
        recentStationIDs.insert(station.id, at: 0)
        if recentStationIDs.count > 10 {
            recentStationIDs = Array(recentStationIDs.prefix(10))
        }
        saveState()
    }

    func addCustomStation(_ station: RadioStation) {
        guard !allStations.contains(where: { $0.id == station.id || $0.streamURL == station.streamURL }) else {
            return
        }
        customStations.insert(station, at: 0)
        saveState()
    }

    func deleteCustomStation(id: String) {
        customStations.removeAll { $0.id == id }
        favoriteIDs.remove(id)
        recentStationIDs.removeAll { $0 == id }
        saveState()
    }

    func addStation(_ station: RadioStation) {
        addCustomStation(station)
    }

    func removeStation(id: String) {
        deleteCustomStation(id: id)
    }

    // MARK: - Persistence

    static var defaultPersistenceURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("MSRU/radio_store.json")
    }

    private func loadState() {
        guard let persistenceURL, FileManager.default.fileExists(atPath: persistenceURL.path) else { return }
        guard let data = try? Data(contentsOf: persistenceURL),
              let payload = try? JSONDecoder().decode(RadioPersistentPayload.self, from: data) else {
            return
        }
        self.customStations = payload.customStations
        self.favoriteIDs = Set(payload.favoriteIDs)
        self.recentStationIDs = payload.recentStationIDs
    }

    private func saveState() {
        guard let persistenceURL else { return }
        let payload = RadioPersistentPayload(
            customStations: customStations,
            favoriteIDs: Array(favoriteIDs),
            recentStationIDs: recentStationIDs
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? FileManager.default.createDirectory(at: persistenceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: persistenceURL, options: .atomic)
    }
}

private struct RadioPersistentPayload: Codable {
    let customStations: [RadioStation]
    let favoriteIDs: [String]
    let recentStationIDs: [String]
}

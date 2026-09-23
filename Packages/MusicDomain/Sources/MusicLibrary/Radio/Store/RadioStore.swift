//
//  RadioStore.swift
//  MSRU
//

import Foundation
import Observation
import GRDB
import MusicDomain

@MainActor
@Observable
public final class RadioStore {

    public private(set) var stations: [RadioStation]
    public private(set) var customStations: [RadioStation] = []
    public private(set) var favoriteIDs: Set<String> = []
    public private(set) var recentStationIDs: [String] = []

    private let db: AppDatabase
    private let legacyPersistenceURL: URL?

    public init(
        stations: [RadioStation] = RadioStation.defaultStations,
        db: AppDatabase = .shared,
        legacyPersistenceURL: URL? = RadioStore.defaultPersistenceURL
    ) {
        self.stations = stations
        self.db = db
        self.legacyPersistenceURL = legacyPersistenceURL
        migrateLegacyFileIfNeeded()
        loadState()
    }

    public convenience init(
        stations: [RadioStation] = RadioStation.defaultStations,
        persistenceURL: URL?
    ) {
        self.init(stations: stations, db: .shared, legacyPersistenceURL: persistenceURL)
    }

    // MARK: - Computed Projections

    public var allStations: [RadioStation] {
        customStations + stations
    }

    public var featuredStations: [RadioStation] {
        allStations.filter(\.isFeatured)
    }

    public var favoriteStations: [RadioStation] {
        allStations.filter { favoriteIDs.contains($0.id) }
    }

    public var recentStations: [RadioStation] {
        recentStationIDs.compactMap { id in
            allStations.first { $0.id == id }
        }
    }

    public func isFavorite(id: String) -> Bool {
        favoriteIDs.contains(id)
    }

    public func isCustomStation(id: String) -> Bool {
        customStations.contains { $0.id == id }
    }

    // MARK: - Filtering

    public func filteredStations(genre: RadioGenre, query: String = "") -> [RadioStation] {
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

    public func toggleFavorite(id: String) {
        if favoriteIDs.contains(id) {
            favoriteIDs.remove(id)
        } else {
            favoriteIDs.insert(id)
        }
        saveState()
    }

    public func recordPlayed(station: RadioStation) {
        recentStationIDs.removeAll { $0 == station.id }
        recentStationIDs.insert(station.id, at: 0)
        if recentStationIDs.count > 10 {
            recentStationIDs = Array(recentStationIDs.prefix(10))
        }
        saveState()
    }

    public func addCustomStation(_ station: RadioStation) {
        guard !allStations.contains(where: { $0.id == station.id || $0.streamURL == station.streamURL }) else {
            return
        }
        customStations.insert(station, at: 0)
        saveState()
    }

    public func deleteCustomStation(id: String) {
        customStations.removeAll { $0.id == id }
        favoriteIDs.remove(id)
        recentStationIDs.removeAll { $0 == id }
        saveState()
    }

    public func addStation(_ station: RadioStation) {
        addCustomStation(station)
    }

    public func removeStation(id: String) {
        deleteCustomStation(id: id)
    }

    // MARK: - Persistence

    public static var defaultPersistenceURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("MSRU/radio_store.json")
    }

    private func migrateLegacyFileIfNeeded() {
        guard let legacyPersistenceURL, FileManager.default.fileExists(atPath: legacyPersistenceURL.path) else { return }
        do {
            let data = try Data(contentsOf: legacyPersistenceURL)
            let payload = try JSONDecoder().decode(RadioPersistentPayload.self, from: data)
            let now = Date()
            try db.dbWriter.write { db in
                for station in payload.customStations {
                    try db.execute(
                        sql: """
                        INSERT OR REPLACE INTO radio_stations
                        (id, title, stream_url, homepage_url, genre, country, language, codec, bitrate_kbps, is_featured, description, artwork_reference, is_custom, created_at)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                        arguments: [
                            station.id,
                            station.name,
                            station.streamURL.absoluteString,
                            station.homepageURL?.absoluteString,
                            station.genre.rawValue,
                            station.country,
                            station.language,
                            station.codec,
                            station.bitrateKbps,
                            station.isFeatured,
                            station.description,
                            station.artworkURL?.absoluteString,
                            true,
                            now
                        ]
                    )
                }

                for favID in payload.favoriteIDs {
                    try db.execute(
                        sql: "INSERT OR REPLACE INTO radio_favorites (station_id) VALUES (?)",
                        arguments: [favID]
                    )
                }

                for (idx, recentID) in payload.recentStationIDs.enumerated() {
                    let playedAt = now.addingTimeInterval(-Double(idx))
                    try db.execute(
                        sql: "INSERT OR REPLACE INTO radio_recents (station_id, played_at) VALUES (?, ?)",
                        arguments: [recentID, playedAt]
                    )
                }
            }
            try? FileManager.default.removeItem(at: legacyPersistenceURL)
            print("[RadioStore] Successfully migrated legacy radio_store.json to SQLite and removed file.")
        } catch {
            print("[RadioStore] Failed migrating legacy radio_store.json: \(error)")
            try? FileManager.default.removeItem(at: legacyPersistenceURL)
        }
    }

    private func loadState() {
        do {
            let (customs, favs, recents) = try db.reader.read { db -> ([RadioStation], Set<String>, [String]) in
                let stationRows = try Row.fetchAll(db, sql: "SELECT * FROM radio_stations WHERE is_custom = 1 ORDER BY created_at DESC")
                var stations: [RadioStation] = []
                for row in stationRows {
                    let id: String = row["id"]
                    let title: String = row["title"]
                    let streamUrlStr: String = row["stream_url"]
                    guard let streamURL = URL(string: streamUrlStr) else { continue }
                    let homepageUrlStr: String? = row["homepage_url"]
                    let homepageURL = homepageUrlStr.flatMap { URL(string: $0) }
                    let genreStr: String? = row["genre"]
                    let genre = genreStr.flatMap { RadioGenre(rawValue: $0) } ?? .all
                    let country: String = row["country"] ?? "Global"
                    let language: String = row["language"] ?? "English"
                    let codec: String = row["codec"] ?? "AAC"
                    let bitrateKbps: Int? = row["bitrate_kbps"]
                    let isFeatured: Bool = row["is_featured"] ?? false
                    let description: String = row["description"] ?? ""
                    let artworkRef: String? = row["artwork_reference"]
                    let artworkURL = artworkRef.flatMap { URL(string: $0) }

                    stations.append(RadioStation(
                        id: id,
                        name: title,
                        description: description,
                        genre: genre,
                        streamURL: streamURL,
                        homepageURL: homepageURL,
                        artworkURL: artworkURL,
                        country: country,
                        language: language,
                        codec: codec,
                        bitrateKbps: bitrateKbps,
                        isFeatured: isFeatured,
                        isCustom: true
                    ))
                }

                let favRows = try Row.fetchAll(db, sql: "SELECT station_id FROM radio_favorites")
                let favIDs = Set(favRows.map { (row: Row) -> String in row["station_id"] })

                let recentRows = try Row.fetchAll(db, sql: "SELECT station_id FROM radio_recents ORDER BY played_at DESC LIMIT 10")
                let recentIDs = recentRows.map { (row: Row) -> String in row["station_id"] }

                return (stations, favIDs, recentIDs)
            }

            self.customStations = customs
            self.favoriteIDs = favs
            self.recentStationIDs = recents
        } catch {
            print("[RadioStore] Failed to load radio state from SQLite: \(error)")
        }
    }

    private func saveState() {
        do {
            try db.dbWriter.write { db in
                try db.execute(sql: "DELETE FROM radio_stations WHERE is_custom = 1")
                let now = Date()
                for (idx, station) in self.customStations.enumerated() {
                    let createdAt = now.addingTimeInterval(-Double(idx))
                    try db.execute(
                        sql: """
                        INSERT OR REPLACE INTO radio_stations
                        (id, title, stream_url, homepage_url, genre, country, language, codec, bitrate_kbps, is_featured, description, artwork_reference, is_custom, created_at)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                        arguments: [
                            station.id,
                            station.name,
                            station.streamURL.absoluteString,
                            station.homepageURL?.absoluteString,
                            station.genre.rawValue,
                            station.country,
                            station.language,
                            station.codec,
                            station.bitrateKbps,
                            station.isFeatured,
                            station.description,
                            station.artworkURL?.absoluteString,
                            true,
                            createdAt
                        ]
                    )
                }

                try db.execute(sql: "DELETE FROM radio_favorites")
                for favID in self.favoriteIDs {
                    try db.execute(
                        sql: "INSERT OR REPLACE INTO radio_favorites (station_id) VALUES (?)",
                        arguments: [favID]
                    )
                }

                try db.execute(sql: "DELETE FROM radio_recents")
                for (idx, recentID) in self.recentStationIDs.enumerated() {
                    let playedAt = now.addingTimeInterval(-Double(idx))
                    try db.execute(
                        sql: "INSERT OR REPLACE INTO radio_recents (station_id, played_at) VALUES (?, ?)",
                        arguments: [recentID, playedAt]
                    )
                }
            }
        } catch {
            print("[RadioStore] Failed to save radio state to SQLite: \(error)")
        }
    }
}

private struct RadioPersistentPayload: Codable {
    public let customStations: [RadioStation]
    public let favoriteIDs: [String]
    public let recentStationIDs: [String]
}

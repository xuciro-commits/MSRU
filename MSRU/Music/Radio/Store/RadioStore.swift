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

    init(stations: [RadioStation] = RadioStation.defaultStations) {
        self.stations = stations
    }

    var featuredStations: [RadioStation] {
        stations.filter(\.isFeatured)
    }

    func filteredStations(genre: RadioGenre, query: String = "") -> [RadioStation] {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return stations.filter { station in
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

    func addStation(_ station: RadioStation) {
        guard !stations.contains(where: { $0.id == station.id }) else { return }
        stations.append(station)
    }

    func removeStation(id: String) {
        stations.removeAll { $0.id == id }
    }
}

//
//  LibraryPresentationAggregator.swift
//  MSRU
//

import Foundation
import AppFoundation

@MainActor
final class LibraryPresentationAggregator {

    static func buildAlbums(from localTracks: [LocalTrack], libraryTracks: [LibraryTrack] = []) -> [AlbumPresentationModel] {
        var albumGroups: [String: [LocalTrack]] = [:]

        for track in localTracks {
            let key = (track.album?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                ? "\(track.artist) — \(track.album!)"
                : "\(track.artist) — Unknown Album"
            albumGroups[key, default: []].append(track)
        }

        var models: [AlbumPresentationModel] = []

        for (key, tracks) in albumGroups {
            guard let first = tracks.first else { continue }
            let artist = first.artist
            let albumTitle = (first.album?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                ? first.album!
                : "Unknown Album"

            let totalDuration = tracks.reduce(0.0) { $0 + $1.duration }

            // Extract tracks with trackNumber heuristic
            let presentationTracks = tracks.enumerated().map { index, track in
                let heuristic = FileNameHeuristicParser.parse(fileName: track.title)
                let trackNum = heuristic.trackNumber ?? (index + 1)
                let displayTitle = heuristic.title.isEmpty ? track.title : heuristic.title
                return TrackPresentationModel(
                    id: track.id,
                    trackNumber: trackNum,
                    title: displayTitle,
                    artist: track.artist,
                    duration: track.duration,
                    formatBadge: track.fileURL.pathExtension.uppercased(),
                    versionCount: 1
                )
            }.sorted { (a: TrackPresentationModel, b: TrackPresentationModel) in
                a.trackNumber < b.trackNumber
            }

            // Try to deduce year
            let year = tracks.compactMap { FileNameHeuristicParser.parse(fileName: $0.title).year }.first

            let disc = DiscTrackGroup(discNumber: 1, discTitle: nil, tracks: presentationTracks)
            let albumArtworkRef = tracks.compactMap(\.artworkReference).first

            let model = AlbumPresentationModel(
                id: key,
                title: albumTitle,
                artist: artist,
                year: year,
                artworkData: nil,
                artworkURL: nil,
                artworkReference: albumArtworkRef,
                trackCount: tracks.count,
                duration: totalDuration,
                audioQualityBadge: tracks.first?.fileURL.pathExtension.lowercased() == "flac" ? "Hi-Res" : "Lossless",
                discs: [disc]
            )
            models.append(model)
        }

        return models.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    static func buildArtists(from localTracks: [LocalTrack], libraryTracks: [LibraryTrack] = []) -> [ArtistPresentationModel] {
        var artistGroups: [String: [LocalTrack]] = [:]

        for track in localTracks {
            let artist = track.artist.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = artist.isEmpty ? "Unknown Artist" : artist
            artistGroups[key, default: []].append(track)
        }

        var models: [ArtistPresentationModel] = []

        for (artistName, tracks) in artistGroups {
            let albumsCount = Set(tracks.compactMap { $0.album }).count
            let artistArtworkRef = tracks.compactMap(\.artworkReference).first
            let model = ArtistPresentationModel(
                id: artistName,
                name: artistName,
                aliases: [],
                country: nil,
                albumCount: max(1, albumsCount),
                trackCount: tracks.count,
                artworkData: nil,
                artworkURL: nil,
                artworkReference: artistArtworkRef
            )
            models.append(model)
        }

        return models.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

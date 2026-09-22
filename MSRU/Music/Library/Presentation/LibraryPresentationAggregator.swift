//
//  LibraryPresentationAggregator.swift
//  MSRU
//

import Foundation
import AppFoundation

@MainActor
final class LibraryPresentationAggregator {

    static func buildAlbums(from localTracks: [LocalTrack], libraryTracks: [LibraryTrack] = []) -> [AlbumPresentationModel] {
        // 1. Group tracks by album title (or artist if unknown)
        var rawAlbumGroups: [String: [LocalTrack]] = [:]

        for track in localTracks {
            let albumKey = (track.album?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                ? track.album!.trimmingCharacters(in: .whitespacesAndNewlines)
                : "Unknown Album (\(track.artist))"
            rawAlbumGroups[albumKey, default: []].append(track)
        }

        var albumGroups: [String: (albumTitle: String, primaryArtist: String, tracks: [LocalTrack])] = [:]

        for (_, tracks) in rawAlbumGroups {
            // Determine primary artist for this album:
            // Find the most frequent artist, or the primary artist before any comma/slash
            let artistCounts = tracks.reduce(into: [String: Int]()) { counts, t in
                counts[t.artist, default: 0] += 1
            }
            let primaryCandidate = artistCounts.max(by: { $0.value < $1.value })?.key ?? tracks.first?.artist ?? "Unknown Artist"
            let primaryArtist: String
            if let firstArt = primaryCandidate.components(separatedBy: CharacterSet(charactersIn: ",/&")).first?.trimmingCharacters(in: .whitespacesAndNewlines), !firstArt.isEmpty {
                primaryArtist = firstArt
            } else {
                primaryArtist = primaryCandidate
            }

            let displayAlbumTitle = (tracks.first?.album?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                ? tracks.first!.album!.trimmingCharacters(in: .whitespacesAndNewlines)
                : "Unknown Album"

            let groupKey = "\(primaryArtist) — \(displayAlbumTitle)"
            albumGroups[groupKey] = (displayAlbumTitle, primaryArtist, tracks)
        }

        var models: [AlbumPresentationModel] = []

        for (key, group) in albumGroups {
            let tracks = group.tracks
            let artist = group.primaryArtist
            let albumTitle = group.albumTitle
            let totalDuration = tracks.reduce(0.0) { $0 + $1.duration }

            // Extract tracks with normalized trackNumber and title
            let presentationTracks = tracks.enumerated().map { index, track in
                let trackNum = track.trackNumber ?? (index + 1)
                return TrackPresentationModel(
                    id: track.id,
                    trackNumber: trackNum,
                    title: track.title,
                    artist: track.artist,
                    duration: track.duration,
                    formatBadge: track.fileURL.pathExtension.uppercased(),
                    versionCount: 1
                )
            }.sorted { (a: TrackPresentationModel, b: TrackPresentationModel) in
                a.trackNumber < b.trackNumber
            }

            // Deduce year from normalized LocalTrack
            let year = tracks.compactMap(\.year).first

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
            let rawArtist = track.artist.trimmingCharacters(in: .whitespacesAndNewlines)
            // If track has guest artists like "Priscilla Chan, Leon Lai", associate with primary artist
            let primaryArtist = rawArtist.components(separatedBy: CharacterSet(charactersIn: ",/&")).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? rawArtist
            let key = primaryArtist.isEmpty ? (rawArtist.isEmpty ? "Unknown Artist" : rawArtist) : primaryArtist
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

//
//  ArtistCreditCleaner.swift
//  MSRU
//
//  Utility for parsing multi-artist credit strings, determining sole vs. shared ownership,
//  and safely removing a target artist from a composite artist credit string.
//

import Foundation

public nonisolated enum ArtistCreditCleaner {

    /// Standard delimiters used in multi-artist credits.
    private static let separators = [
        " feat. ", " Feat. ", " ft. ", " Ft. ",
        " / ", " , ", ", ", " & ", " 和 ", " 与 "
    ]

    /// Returns all individual artist names parsed from a composite credit string.
    public static func parseArtists(from credit: String) -> [String] {
        let trimmed = credit.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var currentTokens = [trimmed]
        for sep in separators {
            currentTokens = currentTokens.flatMap { token in
                token.components(separatedBy: sep)
            }
        }

        // Also split by commas or slashes without surrounding spaces
        currentTokens = currentTokens.flatMap { token in
            token.components(separatedBy: CharacterSet(charactersIn: ",/&"))
        }

        return currentTokens
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Determines if a credit string contains the target artist.
    public static func containsArtist(_ targetArtist: String, in credit: String) -> Bool {
        let cleanTarget = targetArtist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanTarget.isEmpty else { return false }
        let artists = parseArtists(from: credit)
        return artists.contains { $0.lowercased() == cleanTarget }
    }

    /// Determines whether the track is solely owned by the target artist (true)
    /// or is a collaboration with other artists (false).
    public static func isSoleArtist(_ targetArtist: String, in credit: String) -> Bool {
        let cleanTarget = targetArtist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanTarget.isEmpty else { return false }
        let artists = parseArtists(from: credit)
        guard artists.contains(where: { $0.lowercased() == cleanTarget }) else { return false }
        // If there are other artists besides targetArtist, it's NOT sole
        let otherArtists = artists.filter { $0.lowercased() != cleanTarget }
        return otherArtists.isEmpty
    }

    /// Removes targetArtist from the credit string.
    /// Returns the cleaned string containing remaining artists, or `nil` if no other artists remain.
    public static func removingArtist(_ targetArtist: String, from credit: String) -> String? {
        let cleanTarget = targetArtist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanTarget.isEmpty else { return credit }

        let artists = parseArtists(from: credit)
        let remaining = artists.filter { $0.lowercased() != cleanTarget }

        guard !remaining.isEmpty else { return nil }

        if remaining.count == 1 {
            return remaining[0]
        } else {
            return remaining.joined(separator: ", ")
        }
    }
}

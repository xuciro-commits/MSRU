//
//  TrackMetadataOverlay.swift
//  MSRU
//
//  Created for Identity Resolution Engine Phase 1.
//

import Foundation
import AppFoundation
import MusicDomain

/// A three-layer cascading metadata container for a music track or audio asset.
///
/// Implements Roon-style non-destructive metadata management:
/// `User` (manual edits) > `Canonical` (MBID / graph enrichment) > `Raw` (original tag headers).
/// Guarantees that the underlying physical file tag (`raw`) is never mutated or destroyed.
nonisolated public struct TrackMetadataOverlay: Identifiable, Hashable, Codable, Sendable {

    /// Unique identifier for this metadata record (typically aligned with the underlying AudioAsset ID or track ID).
    public let id: String

    /// Optional reference to the underlying physical AudioAsset.
    public var assetID: String?

    // MARK: - Layered Properties

    public var title: OverlayValue<String>
    public var artist: OverlayValue<String>
    public var album: OverlayValue<String>
    public var albumArtist: OverlayValue<String>
    public var trackNumber: OverlayValue<Int>
    public var discNumber: OverlayValue<Int>
    public var year: OverlayValue<Int>
    public var genre: OverlayValue<String>
    public var composer: OverlayValue<String>
    public var comment: OverlayValue<String>

    /// Timestamp of last metadata update.
    public var updatedAt: Date

    // MARK: - Initializers

    public init(
        id: String = UUID().uuidString,
        assetID: String? = nil,
        title: OverlayValue<String> = OverlayValue(),
        artist: OverlayValue<String> = OverlayValue(),
        album: OverlayValue<String> = OverlayValue(),
        albumArtist: OverlayValue<String> = OverlayValue(),
        trackNumber: OverlayValue<Int> = OverlayValue(),
        discNumber: OverlayValue<Int> = OverlayValue(),
        year: OverlayValue<Int> = OverlayValue(),
        genre: OverlayValue<String> = OverlayValue(),
        composer: OverlayValue<String> = OverlayValue(),
        comment: OverlayValue<String> = OverlayValue(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.assetID = assetID
        self.title = title
        self.artist = artist
        self.album = album
        self.albumArtist = albumArtist
        self.trackNumber = trackNumber
        self.discNumber = discNumber
        self.year = year
        self.genre = genre
        self.composer = composer
        self.comment = comment
        self.updatedAt = updatedAt
    }

    /// Convenience initializer creating an overlay directly from raw tag values.
    public init(
        id: String = UUID().uuidString,
        assetID: String? = nil,
        rawTitle: String? = nil,
        rawArtist: String? = nil,
        rawAlbum: String? = nil,
        rawAlbumArtist: String? = nil,
        rawTrackNumber: Int? = nil,
        rawDiscNumber: Int? = nil,
        rawYear: Int? = nil,
        rawGenre: String? = nil,
        rawComposer: String? = nil,
        rawComment: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.assetID = assetID
        self.title = .raw(rawTitle)
        self.artist = .raw(rawArtist)
        self.album = .raw(rawAlbum)
        self.albumArtist = .raw(rawAlbumArtist)
        self.trackNumber = .raw(rawTrackNumber)
        self.discNumber = .raw(rawDiscNumber)
        self.year = .raw(rawYear)
        self.genre = .raw(rawGenre)
        self.composer = .raw(rawComposer)
        self.comment = .raw(rawComment)
        self.updatedAt = updatedAt
    }

    /// Convenience initializer initialized from a `LocalTrack`.
    @MainActor
    public init(from localTrack: LocalTrack, assetID: String? = nil) {
        self.init(
            id: localTrack.id,
            assetID: assetID,
            rawTitle: localTrack.title,
            rawArtist: localTrack.artist,
            rawAlbum: localTrack.album
        )
    }

    // MARK: - Resolved Accessors

    /// The effective title respecting `user ?? canonical ?? raw`.
    public var resolvedTitle: String {
        title.resolved ?? "Unknown Title"
    }

    /// The effective artist respecting `user ?? canonical ?? raw`.
    public var resolvedArtist: String {
        artist.resolved ?? "Unknown Artist"
    }

    /// The effective album name respecting cascading priority.
    public var resolvedAlbum: String? {
        album.resolved
    }

    /// The effective album artist name respecting cascading priority.
    public var resolvedAlbumArtist: String? {
        albumArtist.resolved
    }

    /// The effective track number.
    public var resolvedTrackNumber: Int? {
        trackNumber.resolved
    }

    /// The effective disc number.
    public var resolvedDiscNumber: Int? {
        discNumber.resolved
    }

    /// The effective release year.
    public var resolvedYear: Int? {
        year.resolved
    }

    /// The effective genre string.
    public var resolvedGenre: String? {
        genre.resolved
    }

    /// The effective composer string.
    public var resolvedComposer: String? {
        composer.resolved
    }

    // MARK: - Inspection

    /// Whether any field contains an explicit user override.
    public var hasUserOverrides: Bool {
        title.isOverridden ||
        artist.isOverridden ||
        album.isOverridden ||
        albumArtist.isOverridden ||
        trackNumber.isOverridden ||
        discNumber.isOverridden ||
        year.isOverridden ||
        genre.isOverridden ||
        composer.isOverridden ||
        comment.isOverridden
    }

    /// Whether any field has been enriched with authoritative canonical metadata different from raw.
    public var isEnriched: Bool {
        title.isEnriched ||
        artist.isEnriched ||
        album.isEnriched ||
        albumArtist.isEnriched ||
        trackNumber.isEnriched ||
        discNumber.isEnriched ||
        year.isEnriched ||
        genre.isEnriched ||
        composer.isEnriched ||
        comment.isEnriched
    }

    // MARK: - Batch Canonical Enrichment

    /// Applies canonical values obtained from identity resolution or an external catalog (e.g. MusicBrainz).
    public mutating func applyCanonicalMetadata(
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        albumArtist: String? = nil,
        trackNumber: Int? = nil,
        discNumber: Int? = nil,
        year: Int? = nil,
        genre: String? = nil,
        composer: String? = nil
    ) {
        if let title { self.title.setCanonical(title) }
        if let artist { self.artist.setCanonical(artist) }
        if let album { self.album.setCanonical(album) }
        if let albumArtist { self.albumArtist.setCanonical(albumArtist) }
        if let trackNumber { self.trackNumber.setCanonical(trackNumber) }
        if let discNumber { self.discNumber.setCanonical(discNumber) }
        if let year { self.year.setCanonical(year) }
        if let genre { self.genre.setCanonical(genre) }
        if let composer { self.composer.setCanonical(composer) }
        self.updatedAt = Date()
    }

    // MARK: - Reset Actions

    /// Resets all fields to their authoritative canonical values by discarding user modifications.
    public mutating func resetAllToCanonical() {
        title.resetToCanonical()
        artist.resetToCanonical()
        album.resetToCanonical()
        albumArtist.resetToCanonical()
        trackNumber.resetToCanonical()
        discNumber.resetToCanonical()
        year.resetToCanonical()
        genre.resetToCanonical()
        composer.resetToCanonical()
        comment.resetToCanonical()
        self.updatedAt = Date()
    }

    /// Resets all fields completely back to original raw file tags, clearing both user edits and canonical overrides.
    public mutating func resetAllToRaw() {
        title.resetToRaw()
        artist.resetToRaw()
        album.resetToRaw()
        albumArtist.resetToRaw()
        trackNumber.resetToRaw()
        discNumber.resetToRaw()
        year.resetToRaw()
        genre.resetToRaw()
        composer.resetToRaw()
        comment.resetToRaw()
        self.updatedAt = Date()
    }
}

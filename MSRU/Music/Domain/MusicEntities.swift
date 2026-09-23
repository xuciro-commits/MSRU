//
//  MusicEntities.swift
//  MSRU
//
//  Core music entity models representing musical works, recordings, releases, artists, and media.
//

import Foundation
import AppFoundation
import MusicDomain

// MARK: - ReleaseGroup

/// Primary classification of an album-level release group.
nonisolated public enum ReleaseGroupType: String, Hashable, Codable, Sendable {
    case album
    case single
    case ep
    case broadcast
    case other
    case compilation
    case soundtrack
    case live
    case remix
}

/// An abstract album concept grouping various physical and digital releases together.
///
/// Example: "叶惠美" is the ReleaseGroup.
/// Its constituent releases include the 2003 Taiwan CD, 2003 Hong Kong Edition, 2020 Remastered Vinyl.
nonisolated public struct ReleaseGroup: Identifiable, Hashable, Codable, Sendable {

    /// Stable ReleaseGroup MBID.
    public let id: String

    /// The definitive title of the album concept.
    public var title: String

    /// The credited primary artist for the entire release group (e.g. "Jay Chou" or "Various Artists").
    public var artistCredit: ArtistCredit

    /// The primary album type.
    public var primaryType: ReleaseGroupType

    /// Secondary tags (e.g. soundtrack, compilation).
    public var secondaryTypes: [ReleaseGroupType]

    /// Earliest known release date (e.g. "2003-07-31").
    public var firstReleaseDate: String?

    public init(
        id: String,
        title: String,
        artistCredit: ArtistCredit,
        primaryType: ReleaseGroupType = .album,
        secondaryTypes: [ReleaseGroupType] = [],
        firstReleaseDate: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artistCredit = artistCredit
        self.primaryType = primaryType
        self.secondaryTypes = secondaryTypes
        self.firstReleaseDate = firstReleaseDate
    }
}

// MARK: - Release

/// A concrete physical or digital product issue of a ReleaseGroup.
///
/// Example: "叶惠美 2003 台湾首发版" (Alfa Music CD) or "叶惠美 2020 经典黑胶版".
/// Contains country, date, barcode, and medium discs.
nonisolated public struct Release: Identifiable, Hashable, Codable, Sendable {

    /// Stable Release MBID (e.g. "a1b2c3d4-0000-4000-8000-000000000001").
    public let id: String

    /// Identifier of the parent abstract album concept (`ReleaseGroup`).
    public let releaseGroupID: String

    /// Title as issued on this release.
    public var title: String

    /// Credited artist for this release issue.
    public var artistCredit: ArtistCredit

    /// Release date string (ISO format: "2003-07-31" or "2003").
    public var date: String?

    /// Two-letter country code (e.g. "TW", "US", "JP", "GB").
    public var country: String?

    /// Barcode / UPC / EAN.
    public var barcode: String?

    /// Record label / publishing imprint.
    public var label: String?

    /// Catalog number assigned by label.
    public var catalogueNumber: String?

    /// Physical packaging description.
    public var packaging: String?

    /// Constituent discs / mediums in this release.
    public var media: [Medium]

    public init(
        id: String,
        releaseGroupID: String,
        title: String,
        artistCredit: ArtistCredit,
        date: String? = nil,
        country: String? = nil,
        barcode: String? = nil,
        label: String? = nil,
        catalogueNumber: String? = nil,
        packaging: String? = nil,
        media: [Medium] = []
    ) {
        self.id = id
        self.releaseGroupID = releaseGroupID
        self.title = title
        self.artistCredit = artistCredit
        self.date = date
        self.country = country
        self.barcode = barcode
        self.label = label
        self.catalogueNumber = catalogueNumber
        self.packaging = packaging
        self.media = media
    }

    /// Flattens all tracks across all discs in sequential order.
    public var allTracks: [MusicTrack] {
        media.flatMap(\.tracks)
    }

    /// Total track count across all discs.
    public var totalTrackCount: Int {
        allTracks.count
    }
}

// MARK: - Medium

/// A physical or logical disc, vinyl side, or tape cassette comprising a Release.
nonisolated public struct Medium: Identifiable, Hashable, Codable, Sendable {

    /// Unique medium identifier.
    public let id: String

    /// 1-based disc number (e.g. 1 for Disc 1, 2 for Disc 2).
    public let position: Int

    /// Format of the medium (e.g. "CD", "12\" Vinyl", "Digital Media", "Cassette").
    public var format: String?

    /// Optional disc subtitle (e.g. "Bonus Disc", "The Remixes").
    public var title: String?

    /// Ordered tracks sequenced on this medium.
    public var tracks: [MusicTrack]

    public init(
        id: String = UUID().uuidString,
        position: Int,
        format: String? = "Digital Media",
        title: String? = nil,
        tracks: [MusicTrack] = []
    ) {
        self.id = id
        self.position = position
        self.format = format
        self.title = title
        self.tracks = tracks
    }

    /// Total track count on this medium.
    public var trackCount: Int {
        tracks.count
    }
}

// MARK: - MusicTrack

/// A single track as sequenced on a specific Medium of a Release.
///
/// Distinct from `Recording`: a Recording represents the performance capture,
/// while `MusicTrack` represents its position and title on a CD/disc.
nonisolated public struct MusicTrack: Identifiable, Hashable, Codable, Sendable {

    /// Stable Track MBID or generated ID.
    public let id: String

    /// Identifier of the audio recording contained on this track.
    public let recordingID: String

    /// 1-based sequential position on this medium (e.g. 1, 2, 3...).
    public let position: Int

    /// Track number string as printed on sleeve/cue (e.g. "01", "A1", "B2").
    public let number: String

    /// Title of the track on this specific release.
    public let title: String

    /// Specific track artist credit if different from the album release artist.
    public let artistCredit: ArtistCredit?

    /// Duration of the track on this medium in seconds.
    public let duration: TimeInterval?

    public init(
        id: String,
        recordingID: String,
        position: Int,
        number: String? = nil,
        title: String,
        artistCredit: ArtistCredit? = nil,
        duration: TimeInterval? = nil
    ) {
        self.id = id
        self.recordingID = recordingID
        self.position = position
        self.number = number ?? "\(position)"
        self.title = title
        self.artistCredit = artistCredit
        self.duration = duration
    }
}

// MARK: - Recording

/// A unique audio performance capture of a musical work.
///
/// Anchored by an acoustic identity (e.g. AcoustID) and MBID.
/// Studio version vs Live 1994 are separate Recordings of the same Work.
nonisolated public struct Recording: Identifiable, Hashable, Codable, Sendable {

    /// Stable Recording MBID (e.g. "a225bb13-5b8f-4da0-9908-410a563f8582").
    public let id: String

    /// The title of this recording.
    public var title: String

    /// Credited artists performing on this recording.
    public var artistCredit: ArtistCredit

    /// Reference to the underlying abstract musical work, if identified.
    public var workID: String?

    /// Expected reference duration of this recording in seconds.
    public var duration: TimeInterval?

    /// International Standard Recording Code (ISRC), if known.
    public var isrc: String?

    /// Whether this recording is a live performance capture.
    public var isLive: Bool

    /// Acoustic fingerprint reference (AcoustID).
    public var acoustID: String?

    public init(
        id: String,
        title: String,
        artistCredit: ArtistCredit,
        workID: String? = nil,
        duration: TimeInterval? = nil,
        isrc: String? = nil,
        isLive: Bool = false,
        acoustID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artistCredit = artistCredit
        self.workID = workID
        self.duration = duration
        self.isrc = isrc
        self.isLive = isLive
        self.acoustID = acoustID
    }
}

// MARK: - Work

/// The genre/structure category of a musical work.
nonisolated public enum WorkType: String, Hashable, Codable, Sendable {
    case song
    case symphony
    case concerto
    case sonata
    case soundtrack
    case aria
    case suite
    case instrumental
    case poem
    case other
}

/// An abstract distinct musical composition or intellectual creation.
///
/// Distinct from any particular audio performance or release.
/// For example, "晴天" (composed & written by Jay Chou) or "Symphony No. 9 in D minor, Op. 125" (Beethoven).
nonisolated public struct Work: Identifiable, Hashable, Codable, Sendable {

    /// Stable Work identifier (e.g. MusicBrainz Work MBID).
    public let id: String

    /// The title of the work.
    public var title: String

    /// The structural work type.
    public var workType: WorkType

    /// Composers credited for the composition.
    public var composers: [ArtistEntity]

    /// Lyricists credited for words/lyrics.
    public var lyricists: [ArtistEntity]

    /// International Standard Musical Work Code (ISWC), if known.
    public var iswc: String?

    public init(
        id: String,
        title: String,
        workType: WorkType = .song,
        composers: [ArtistEntity] = [],
        lyricists: [ArtistEntity] = [],
        iswc: String? = nil
    ) {
        self.id = id
        self.title = title
        self.workType = workType
        self.composers = composers
        self.lyricists = lyricists
        self.iswc = iswc
    }
}

// MARK: - ArtistEntity

/// An immutable identity representing a musical artist, band, orchestra, or composer.
///
/// Anchored by a stable identifier (e.g. MusicBrainz MBID).
/// Displays localized names according to `aliasCollection` and user locale.
nonisolated public struct ArtistEntity: Identifiable, Hashable, Codable, Sendable {

    /// Stable identity (e.g. MusicBrainz MBID: "0d79768b-9842-4215-b44c-0062c66f50b2")
    public let id: String

    /// Localized name aliases and canonical name.
    public var aliasCollection: EntityAliasCollection

    /// Disambiguation comment (e.g. "Taiwanese singer-songwriter", "UK indie rock band").
    public var disambiguation: String?

    /// Two-letter country code or territory.
    public var country: String?

    /// Activity date start (e.g. "1979-01-18").
    public var beginDate: String?

    /// Activity date end if disbanded or deceased.
    public var endDate: String?

    public init(
        id: String,
        canonicalName: String,
        aliases: [EntityAlias] = [],
        disambiguation: String? = nil,
        country: String? = nil,
        beginDate: String? = nil,
        endDate: String? = nil
    ) {
        self.id = id
        self.aliasCollection = EntityAliasCollection(
            canonicalName: canonicalName,
            aliases: aliases
        )
        self.disambiguation = disambiguation
        self.country = country
        self.beginDate = beginDate
        self.endDate = endDate
    }

    /// The definitive reference canonical name for the artist.
    public var canonicalName: String {
        aliasCollection.canonicalName
    }

    /// Resolves the optimal display name given preferred locales (e.g. zh-Hans -> 周杰伦, en -> Jay Chou).
    public func displayName(preferredLocales: [Locale] = [Locale.current]) -> String {
        aliasCollection.displayName(preferredLocales: preferredLocales)
    }
}

// MARK: - ArtistCredit

/// The functional role an artist played on a recording or release.
nonisolated public enum ArtistRole: String, Hashable, Codable, Sendable {
    case primary
    case featured
    case producer
    case remixer
    case composer
    case lyricist
    case arranger
    case conductor
    case performer
}

/// An individual artist's participation within an `ArtistCredit`.
nonisolated public struct ArtistParticipation: Identifiable, Hashable, Codable, Sendable {

    public var id: String {
        "\(artist.id):\(role.rawValue)"
    }

    /// The underlying immutable artist entity.
    public let artist: ArtistEntity

    /// The specific role played.
    public let role: ArtistRole

    /// Connecting string (e.g. " feat. ", " & ", " with ").
    public let joinPhrase: String?

    public init(
        artist: ArtistEntity,
        role: ArtistRole = .primary,
        joinPhrase: String? = nil
    ) {
        self.artist = artist
        self.role = role
        self.joinPhrase = joinPhrase
    }
}

/// Separates presentation display string from underlying constituent artist entities.
///
/// Example:
/// Headline: "Taylor Swift feat. Post Malone"
/// Participations: [Taylor Swift (primary), Post Malone (featured)]
///
/// Prevents creating monolithic pseudo-artists like "Taylor Swift feat. Post Malone".
nonisolated public struct ArtistCredit: Hashable, Codable, Sendable {

    /// The exact credited string as presented on the release/track.
    public let headline: String

    /// The individual constituent artists and their relationships.
    public let participations: [ArtistParticipation]

    public init(
        headline: String,
        participations: [ArtistParticipation]
    ) {
        self.headline = headline
        self.participations = participations
    }

    /// Convenience initializer for a single primary artist.
    public init(single artist: ArtistEntity) {
        self.headline = artist.canonicalName
        self.participations = [
            ArtistParticipation(artist: artist, role: .primary)
        ]
    }

    /// Convenience initializer for primary + featured artist.
    public init(
        primary: ArtistEntity,
        featured: [ArtistEntity],
        customHeadline: String? = nil
    ) {
        var parts: [ArtistParticipation] = [
            ArtistParticipation(artist: primary, role: .primary, joinPhrase: featured.isEmpty ? nil : " feat. ")
        ]
        for (index, feat) in featured.enumerated() {
            let isLast = index == featured.count - 1
            parts.append(
                ArtistParticipation(artist: feat, role: .featured, joinPhrase: isLast ? nil : ", ")
            )
        }
        self.participations = parts
        if let customHeadline {
            self.headline = customHeadline
        } else if featured.isEmpty {
            self.headline = primary.canonicalName
        } else {
            let featString = featured.map(\.canonicalName).joined(separator: ", ")
            self.headline = "\(primary.canonicalName) feat. \(featString)"
        }
    }

    /// All constituent primary artists.
    public var primaryArtists: [ArtistEntity] {
        participations.filter { $0.role == .primary }.map(\.artist)
    }

    /// All constituent featured artists.
    public var featuredArtists: [ArtistEntity] {
        participations.filter { $0.role == .featured }.map(\.artist)
    }
}

// MARK: - AudioAsset

/// A concrete physical audio file stored on local or attached storage.
///
/// Distinct from `Recording` (the performance) and `MusicTrack` (the disc slot).
/// Multiple AudioAssets may represent the same Recording (e.g. FLAC 24/96 master vs MP3 mobile copy).
nonisolated public struct AudioAsset: Identifiable, Hashable, Codable, Sendable {

    /// Unique asset identifier.
    public let id: String

    /// Physical file location on local disk.
    public let fileURL: URL

    /// File size in bytes.
    public let fileSize: Int64

    /// Cryptographic SHA256 checksum for byte-level duplicate detection.
    public var sha256: String?

    /// Audio container/codec format string (e.g. "FLAC", "WAV", "AAC", "MP3").
    public let format: String

    /// Quantization bit depth (e.g. "16-bit", "24-bit").
    public let bitDepth: String?

    /// Sampling rate in Hz (e.g. 44100, 48000, 96000, 192000).
    public let sampleRate: Double

    /// Approximate or exact bitrate in kilobits per second.
    public let bitrateKbps: Int?

    /// Playback duration in seconds.
    public let duration: TimeInterval

    /// Chromaprint / AcoustID fingerprint hash string for content-based recognition.
    public var acoustID: String?

    /// Associated Recording entity MBID, once identified.
    public var recordingID: String?

    public init(
        id: String = UUID().uuidString,
        fileURL: URL,
        fileSize: Int64 = 0,
        sha256: String? = nil,
        format: String,
        bitDepth: String? = nil,
        sampleRate: Double = 44100,
        bitrateKbps: Int? = nil,
        duration: TimeInterval = 0,
        acoustID: String? = nil,
        recordingID: String? = nil
    ) {
        self.id = id
        self.fileURL = fileURL
        self.fileSize = fileSize
        self.sha256 = sha256
        self.format = format.uppercased()
        self.bitDepth = bitDepth
        self.sampleRate = sampleRate
        self.bitrateKbps = bitrateKbps
        self.duration = duration
        self.acoustID = acoustID
        self.recordingID = recordingID
    }

    /// Whether this asset represents a lossless encoding.
    public var isLossless: Bool {
        ["FLAC", "WAV", "AIFF", "AIF", "ALAC", "DTS"].contains(format)
    }

    /// Whether this asset meets high-resolution audio criteria (> 48 kHz or 24-bit).
    public var isHiRes: Bool {
        sampleRate > 48000 || bitDepth == "24-bit"
    }
}

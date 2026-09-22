//
//  LibrarySurfaceContracts.swift
//  MSRU
//
//  Semantic UpdatePlan contract for AppKit virtualized library surfaces (Table & Collection).
//

import Foundation
import AppFoundation

#if canImport(AppKit)
import AppKit

/// Semantic update plan calculated before touching the virtualized view hierarchy.
nonisolated public enum LibrarySurfaceUpdatePlan: Sendable, Equatable {
    /// Total count or structural ordering has changed (filter, sort, initial load).
    case structural(revision: UInt64, totalCount: Int)

    /// Specific item data has changed (metadata edit, favorite toggled).
    case content(changedIDs: Set<String>)

    /// Active playing item has changed (at most 2 rows updated).
    case playbackIdentity(oldID: String?, newID: String?, isPlaying: Bool)

    /// Selection set changed (selection index set updated without cell re-renders).
    case selection(selectedIDs: Set<String>)

    /// Artwork thumbnail decoded for an asset.
    case artworkReady(reference: String)

    /// Parent SwiftUI view re-rendered due to unrelated state (zero work performed).
    case noOp
}

/// Interaction delegate callback contract from native surfaces to SwiftUI feature container.
@MainActor
public protocol LibrarySurfaceDelegate: AnyObject {
    func surfaceDidSelect(ids: Set<String>)
    func surfaceDidActivate(id: String) // Double-click / Enter
    func surfaceDidToggleFavorite(id: String)
    func surfaceWillDisplay(indices: IndexSet)
    func surfaceDidRequestContextMenu(forID id: String, event: NSEvent) -> NSMenu?
}

public extension LibrarySurfaceDelegate {
    func surfaceDidToggleFavorite(id: String) {}
    func surfaceWillDisplay(indices: IndexSet) {}
    func surfaceDidRequestContextMenu(forID id: String, event: NSEvent) -> NSMenu? { nil }
}

/// Lightweight presentation model for virtualized card grids (Tracks, Albums, Playlists, Artists).
nonisolated public struct LibraryCardSummary: Identifiable, Sendable, Hashable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let secondaryText: String?
    public let badgeText: String?
    public let durationText: String?
    public let artworkReference: String?
    public let isCircularArtwork: Bool
    public var isFavorite: Bool
    public var isSaved: Bool

    public init(
        id: String,
        title: String,
        subtitle: String,
        secondaryText: String? = nil,
        badgeText: String? = nil,
        durationText: String? = nil,
        artworkReference: String? = nil,
        isCircularArtwork: Bool = false,
        isFavorite: Bool = false,
        isSaved: Bool = false
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.secondaryText = secondaryText
        self.badgeText = badgeText
        self.durationText = durationText
        self.artworkReference = artworkReference
        self.isCircularArtwork = isCircularArtwork
        self.isFavorite = isFavorite
        self.isSaved = isSaved
    }
}

/// Data source abstraction allowing NSCollectionView to present 100K+ cards without materializing all in memory.
@MainActor
public protocol LibraryCardDataSource: AnyObject {
    var totalCount: Int { get }
    func item(at index: Int) -> LibraryCardSummary?
    func prefetch(range: Range<Int>)
}

/// In-memory array backed data source for card grids.
@MainActor
public final class ArrayLibraryCardDataSource: LibraryCardDataSource {
    private let items: [LibraryCardSummary]
    public var totalCount: Int { items.count }

    public init(items: [LibraryCardSummary]) {
        self.items = items
    }

    public func item(at index: Int) -> LibraryCardSummary? {
        guard index >= 0 && index < items.count else { return nil }
        return items[index]
    }

    public func prefetch(range: Range<Int>) {}
}

/// Data source abstraction allowing NSTableView to present 500K rows without materializing all in memory.
@MainActor
public protocol LibraryTableDataSource: AnyObject {
    var totalCount: Int { get }
    func item(at index: Int) -> TrackRowSummary?
    func prefetch(range: Range<Int>)
}

/// In-memory array backed data source for smaller collections or previews.
@MainActor
public final class ArrayLibraryTableDataSource: LibraryTableDataSource {
    private let items: [TrackRowSummary]
    public var totalCount: Int { items.count }

    public init(items: [TrackRowSummary]) {
        self.items = items
    }

    public func item(at index: Int) -> TrackRowSummary? {
        guard index >= 0 && index < items.count else { return nil }
        return items[index]
    }

    public func prefetch(range: Range<Int>) {}
}

/// Scalable PagedQueryResult backed data source for 100K-500K rows.
@MainActor
public final class PagedQueryResultDataSource: LibraryTableDataSource {
    private let queryResult: any LibraryQueryResult
    private var localItemCache: [Int: TrackRowSummary] = [:]
    private var inFlightPages = Set<Int>()
    public var onPageLoaded: ((IndexSet) -> Void)?

    public var totalCount: Int { queryResult.totalCount }

    public init(queryResult: any LibraryQueryResult) {
        self.queryResult = queryResult
    }

    public func item(at index: Int) -> TrackRowSummary? {
        if let cached = localItemCache[index] {
            return cached
        }
        prefetch(range: max(0, index - 20) ..< min(totalCount, index + 60))
        return nil
    }

    public func prefetch(range: Range<Int>) {
        guard totalCount > 0 else { return }
        let startPage = range.lowerBound / 128
        let endPage = max(startPage, (range.upperBound - 1) / 128)

        for p in startPage...endPage {
            guard !inFlightPages.contains(p) else { continue }
            inFlightPages.insert(p)

            Task { @MainActor [weak self] in
                guard let self else { return }
                let pStart = p * 128
                let pEnd = min(self.totalCount, (p + 1) * 128)
                guard pStart < pEnd else {
                    self.inFlightPages.remove(p)
                    return
                }

                if let rows = try? await self.queryResult.fetch(range: pStart..<pEnd) {
                    var indices = IndexSet()
                    for (offset, row) in rows.enumerated() {
                        let rowIdx = pStart + offset
                        self.localItemCache[rowIdx] = row
                        indices.insert(rowIdx)
                    }
                    self.inFlightPages.remove(p)
                    self.onPageLoaded?(indices)
                } else {
                    self.inFlightPages.remove(p)
                }
            }
        }
    }
}

/// Scalable PagedQueryResult backed data source for card grids.
@MainActor
public final class PagedQueryResultGridDataSource: LibraryCardDataSource {
    private let queryResult: any LibraryQueryResult
    private var localItemCache: [Int: LibraryCardSummary] = [:]
    private var inFlightPages = Set<Int>()
    public var onPageLoaded: ((IndexSet) -> Void)?

    public var totalCount: Int { queryResult.totalCount }

    public init(queryResult: any LibraryQueryResult) {
        self.queryResult = queryResult
    }

    public func item(at index: Int) -> LibraryCardSummary? {
        if let cached = localItemCache[index] {
            return cached
        }
        prefetch(range: max(0, index - 20) ..< min(totalCount, index + 60))
        return nil
    }

    public func prefetch(range: Range<Int>) {
        guard totalCount > 0 else { return }
        let startPage = range.lowerBound / 128
        let endPage = max(startPage, (range.upperBound - 1) / 128)

        for p in startPage...endPage {
            guard !inFlightPages.contains(p) else { continue }
            inFlightPages.insert(p)

            Task { @MainActor [weak self] in
                guard let self else { return }
                let pStart = p * 128
                let pEnd = min(self.totalCount, (p + 1) * 128)
                guard pStart < pEnd else {
                    self.inFlightPages.remove(p)
                    return
                }

                if let rows = try? await self.queryResult.fetch(range: pStart..<pEnd) {
                    var indices = IndexSet()
                    for (offset, row) in rows.enumerated() {
                        let rowIdx = pStart + offset
                        self.localItemCache[rowIdx] = row.toCardSummary()
                        indices.insert(rowIdx)
                    }
                    self.inFlightPages.remove(p)
                    self.onPageLoaded?(indices)
                } else {
                    self.inFlightPages.remove(p)
                }
            }
        }
    }
}

public extension TrackRowSummary {
    func toCardSummary(isPlaying: Bool = false, isSaved: Bool = false) -> LibraryCardSummary {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        let dur = duration > 0 ? String(format: "%d:%02d", mins, secs) : nil
        return LibraryCardSummary(
            id: id,
            title: title,
            subtitle: artist,
            secondaryText: album,
            badgeText: nil,
            durationText: dur,
            artworkReference: artworkReference,
            isCircularArtwork: false,
            isFavorite: isFavorite,
            isSaved: isSaved
        )
    }
}

public extension AlbumCardSummary {
    func toCardSummary() -> LibraryCardSummary {
        let yearText = year.map { String($0) }
        let tracksText = trackCount > 0 ? "\(trackCount) tracks" : nil
        let sec = [yearText, tracksText].compactMap { $0 }.joined(separator: " · ")
        return LibraryCardSummary(
            id: id,
            title: title,
            subtitle: artist,
            secondaryText: sec.isEmpty ? nil : sec,
            artworkReference: artworkReference
        )
    }
}

public extension ArtistCardSummary {
    func toCardSummary() -> LibraryCardSummary {
        let albumsText = albumCount > 0 ? "\(albumCount) albums" : nil
        let tracksText = trackCount > 0 ? "\(trackCount) tracks" : nil
        let sec = [albumsText, tracksText].compactMap { $0 }.joined(separator: " · ")
        return LibraryCardSummary(
            id: id,
            title: name,
            subtitle: sec.isEmpty ? "Artist" : sec,
            isCircularArtwork: true
        )
    }
}

public extension AlbumPresentationModel {
    func toCardSummary() -> LibraryCardSummary {
        let yearText = year.map { String($0) }
        let tracksText = trackCount > 0 ? "\(trackCount) tracks" : nil
        let sec = [yearText, tracksText].compactMap { $0 }.joined(separator: " · ")
        return LibraryCardSummary(
            id: id,
            title: title,
            subtitle: artist,
            secondaryText: sec.isEmpty ? nil : sec,
            badgeText: audioQualityBadge,
            artworkReference: artworkReference
        )
    }
}

public extension ArtistPresentationModel {
    func toCardSummary() -> LibraryCardSummary {
        let albumsText = albumCount > 0 ? "\(albumCount) albums" : nil
        let tracksText = trackCount > 0 ? "\(trackCount) tracks" : nil
        let sec = [albumsText, tracksText].compactMap { $0 }.joined(separator: " · ")
        return LibraryCardSummary(
            id: id,
            title: name,
            subtitle: sec.isEmpty ? "Artist" : sec,
            artworkReference: artworkReference,
            isCircularArtwork: true
        )
    }
}

public extension Playlist {
    func toCardSummary() -> LibraryCardSummary {
        LibraryCardSummary(
            id: id.uuidString,
            title: title,
            subtitle: "\(trackCount) songs",
            secondaryText: description,
            artworkReference: artworkReference
        )
    }
}
#endif

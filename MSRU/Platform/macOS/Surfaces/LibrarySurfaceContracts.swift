//
//  LibrarySurfaceContracts.swift
//  MSRU
//
//  Semantic UpdatePlan contract for AppKit virtualized library surfaces (Table & Collection).
//

import Foundation

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
#endif

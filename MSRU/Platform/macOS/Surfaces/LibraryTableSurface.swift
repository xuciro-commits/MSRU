//
//  LibraryTableSurface.swift
//  MSRU
//
//  High-performance AppKit NSTableView wrapper for 100K-500K item library browsing.
//  Uses virtualized cell reuse, paged prefetching, and Semantic UpdatePlans.
//

import SwiftUI

#if canImport(AppKit)
import AppKit

public struct LibraryTableSurface: NSViewRepresentable {
    public let revision: UInt64
    public let dataSource: any LibraryTableDataSource
    public let selectedIDs: Set<String>
    public let playingTrackID: String?
    public let isPlaying: Bool
    public weak var delegate: (any LibrarySurfaceDelegate)?

    /// Primary initializer taking a scalable LibraryTableDataSource (such as PagedQueryResultDataSource).
    public init(
        revision: UInt64,
        dataSource: any LibraryTableDataSource,
        selectedIDs: Set<String> = [],
        playingTrackID: String? = nil,
        isPlaying: Bool = false,
        delegate: (any LibrarySurfaceDelegate)? = nil
    ) {
        self.revision = revision
        self.dataSource = dataSource
        self.selectedIDs = selectedIDs
        self.playingTrackID = playingTrackID
        self.isPlaying = isPlaying
        self.delegate = delegate
    }

    /// Convenience initializer taking an in-memory array of row summaries.
    public init(
        revision: UInt64,
        items: [TrackRowSummary],
        selectedIDs: Set<String> = [],
        playingTrackID: String? = nil,
        isPlaying: Bool = false,
        delegate: (any LibrarySurfaceDelegate)? = nil
    ) {
        self.init(
            revision: revision,
            dataSource: ArrayLibraryTableDataSource(items: items),
            selectedIDs: selectedIDs,
            playingTrackID: playingTrackID,
            isPlaying: isPlaying,
            delegate: delegate
        )
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        let tableView = NSTableView()
        tableView.headerView = NSTableHeaderView()
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.rowHeight = 36.0
        tableView.allowsMultipleSelection = true
        tableView.style = .plain
        tableView.backgroundColor = .clear

        // Columns
        let colIndex = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("col_index"))
        colIndex.title = "#"
        colIndex.width = 36
        colIndex.minWidth = 32
        colIndex.maxWidth = 44
        tableView.addTableColumn(colIndex)

        let colTitle = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("col_title"))
        colTitle.title = "Title"
        colTitle.width = 240
        colTitle.minWidth = 150
        tableView.addTableColumn(colTitle)

        let colArtist = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("col_artist"))
        colArtist.title = "Artist"
        colArtist.width = 160
        colArtist.minWidth = 100
        tableView.addTableColumn(colArtist)

        let colAlbum = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("col_album"))
        colAlbum.title = "Album"
        colAlbum.width = 160
        colAlbum.minWidth = 100
        tableView.addTableColumn(colAlbum)

        let colDuration = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("col_duration"))
        colDuration.title = "Duration"
        colDuration.width = 65
        colDuration.minWidth = 50
        colDuration.maxWidth = 80
        tableView.addTableColumn(colDuration)

        let colFav = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("col_fav"))
        colFav.title = "Favorite"
        colFav.width = 40
        colFav.minWidth = 36
        colFav.maxWidth = 48
        tableView.addTableColumn(colFav)

        tableView.dataSource = context.coordinator
        tableView.delegate = context.coordinator
        tableView.doubleAction = #selector(Coordinator.tableViewDoubleAction(_:))
        tableView.target = context.coordinator

        scrollView.documentView = tableView
        context.coordinator.tableView = tableView
        context.coordinator.bindDataSource()

        return scrollView
    }

    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.bindDataSource()
        context.coordinator.applyUpdatePlan()
    }

    // MARK: - Coordinator

    @MainActor
    public final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var parent: LibraryTableSurface
        weak var tableView: NSTableView?

        private var lastAppliedRevision: UInt64 = 0
        private var lastTotalCount: Int = 0
        private var lastPlayingID: String? = nil
        private var lastSelection: Set<String> = []

        init(parent: LibraryTableSurface) {
            self.parent = parent
        }

        func bindDataSource() {
            if let pagedDS = parent.dataSource as? PagedQueryResultDataSource {
                pagedDS.onPageLoaded = { [weak self] indices in
                    guard let self, let tv = self.tableView else { return }
                    let colSet = IndexSet(integersIn: 0..<tv.numberOfColumns)
                    tv.reloadData(forRowIndexes: indices, columnIndexes: colSet)
                }
            }
        }

        func applyUpdatePlan() {
            guard let tableView else { return }

            let currentCount = parent.dataSource.totalCount

            // 1. Revision / Structure change
            if parent.revision != lastAppliedRevision || currentCount != lastTotalCount {
                lastAppliedRevision = parent.revision
                lastTotalCount = currentCount
                lastPlayingID = parent.playingTrackID
                lastSelection = parent.selectedIDs

                tableView.reloadData()
                return
            }

            // 2. Playback Identity change (Update only visible rows matching old and new track)
            if parent.playingTrackID != lastPlayingID {
                lastPlayingID = parent.playingTrackID

                let visibleRows = tableView.rows(in: tableView.visibleRect)
                if visibleRows.length > 0 {
                    let colSet = IndexSet(integersIn: 0..<tableView.numberOfColumns)
                    let rowSet = IndexSet(integersIn: visibleRows.location..<(visibleRows.location + visibleRows.length))
                    tableView.reloadData(forRowIndexes: rowSet, columnIndexes: colSet)
                }
            }

            // 3. Selection change only (Zero cell content re-renders)
            if parent.selectedIDs != lastSelection {
                lastSelection = parent.selectedIDs
            }

            // 4. Otherwise: NO-OP! Zero O(N) work performed.
        }

        // MARK: - NSTableViewDataSource

        public func numberOfRows(in tableView: NSTableView) -> Int {
            parent.dataSource.totalCount
        }

        // MARK: - NSTableViewDelegate

        public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard row < parent.dataSource.totalCount, let colID = tableColumn?.identifier.rawValue else {
                return nil
            }

            let maybeItem = parent.dataSource.item(at: row)
            let isCurrent = (maybeItem?.id == parent.playingTrackID)

            let cellID = NSUserInterfaceItemIdentifier("cell_\(colID)")
            var cell = tableView.makeView(withIdentifier: cellID, owner: nil) as? NSTableCellView

            if cell == nil {
                cell = NSTableCellView()
                cell?.identifier = cellID
                let textField = NSTextField(labelWithString: "")
                textField.lineBreakMode = .byTruncatingTail
                textField.autoresizingMask = [.width, .height]
                textField.isBezeled = false
                textField.drawsBackground = false
                textField.isEditable = false
                cell?.textField = textField
                cell?.addSubview(textField)
            }

            guard let item = maybeItem else {
                // Placeholder skeleton while page is loading asynchronously
                cell?.textField?.stringValue = (colID == "col_index") ? "\(row + 1)" : "..."
                cell?.textField?.textColor = .tertiaryLabelColor
                return cell
            }

            switch colID {
            case "col_index":
                let text = isCurrent ? (parent.isPlaying ? "▶" : "❚❚") : "\(row + 1)"
                cell?.textField?.stringValue = text
                cell?.textField?.alignment = .center
                cell?.textField?.textColor = isCurrent ? .controlAccentColor : .secondaryLabelColor

            case "col_title":
                cell?.textField?.stringValue = item.title
                cell?.textField?.font = .systemFont(ofSize: 13, weight: isCurrent ? .semibold : .regular)
                cell?.textField?.textColor = isCurrent ? .controlAccentColor : .labelColor

            case "col_artist":
                cell?.textField?.stringValue = item.artist
                cell?.textField?.textColor = .secondaryLabelColor

            case "col_album":
                cell?.textField?.stringValue = item.album ?? "—"
                cell?.textField?.textColor = .secondaryLabelColor

            case "col_duration":
                let mins = Int(item.duration) / 60
                let secs = Int(item.duration) % 60
                cell?.textField?.stringValue = String(format: "%d:%02d", mins, secs)
                cell?.textField?.alignment = .right
                cell?.textField?.textColor = .secondaryLabelColor
                cell?.textField?.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)

            case "col_fav":
                cell?.textField?.stringValue = item.isFavorite ? "♥" : ""
                cell?.textField?.textColor = .systemRed
                cell?.textField?.alignment = .center

            default:
                break
            }

            // Viewport prefetching for thumbnails
            if let artRef = item.artworkReference, row % 20 == 0 {
                ArtworkLoader.shared.prefetch(references: [artRef], bucket: .pt32)
            }

            return cell
        }

        public func tableViewSelectionDidChange(_ notification: Notification) {
            guard let tableView else { return }
            let selectedIndexes = tableView.selectedRowIndexes
            var selected = Set<String>()
            for idx in selectedIndexes {
                if let item = parent.dataSource.item(at: idx) {
                    selected.insert(item.id)
                }
            }
            lastSelection = selected
            parent.delegate?.surfaceDidSelect(ids: selected)
        }

        @objc func tableViewDoubleAction(_ sender: AnyObject) {
            guard let tableView else { return }
            let clickedRow = tableView.clickedRow
            guard clickedRow >= 0, let item = parent.dataSource.item(at: clickedRow) else { return }
            parent.delegate?.surfaceDidActivate(id: item.id)
        }
    }
}
#endif

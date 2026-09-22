//
//  LibraryGridSurface.swift
//  MSRU
//
//  High-performance AppKit NSCollectionView wrapper for virtualized card grids (Tracks, Albums, Playlists, Artists).
//  Uses physical cell recycling, zero SwiftUI placement overhead, and semantic UpdatePlans.
//

import SwiftUI

#if canImport(AppKit)
import AppKit

public struct LibraryGridSurface<Header: View>: NSViewRepresentable {
    public let revision: UInt64
    public let dataSource: any LibraryCardDataSource
    public let selectedIDs: Set<String>
    public let playingTrackID: String?
    public let isPlaying: Bool
    public let itemSize: CGSize
    public let contentBottomInset: CGFloat
    public let headerContent: Header?
    public weak var delegate: (any LibrarySurfaceDelegate)?

    public var hasHeader: Bool {
        headerContent != nil && !(Header.self == EmptyView.self)
    }

    public init(
        revision: UInt64,
        dataSource: any LibraryCardDataSource,
        selectedIDs: Set<String> = [],
        playingTrackID: String? = nil,
        isPlaying: Bool = false,
        itemSize: CGSize = CGSize(width: 170, height: 236),
        contentBottomInset: CGFloat = 100,
        delegate: (any LibrarySurfaceDelegate)? = nil,
        @ViewBuilder header: () -> Header
    ) {
        self.revision = revision
        self.dataSource = dataSource
        self.selectedIDs = selectedIDs
        self.playingTrackID = playingTrackID
        self.isPlaying = isPlaying
        self.itemSize = itemSize
        self.contentBottomInset = contentBottomInset
        self.delegate = delegate
        self.headerContent = header()
    }

    public init(
        revision: UInt64,
        items: [LibraryCardSummary],
        selectedIDs: Set<String> = [],
        playingTrackID: String? = nil,
        isPlaying: Bool = false,
        itemSize: CGSize = CGSize(width: 170, height: 236),
        contentBottomInset: CGFloat = 100,
        delegate: (any LibrarySurfaceDelegate)? = nil,
        @ViewBuilder header: () -> Header
    ) {
        self.init(
            revision: revision,
            dataSource: ArrayLibraryCardDataSource(items: items),
            selectedIDs: selectedIDs,
            playingTrackID: playingTrackID,
            isPlaying: isPlaying,
            itemSize: itemSize,
            contentBottomInset: contentBottomInset,
            delegate: delegate,
            header: header
        )
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.scrollerStyle = .overlay
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.automaticallyAdjustsContentInsets = false

        let flowLayout = NSCollectionViewFlowLayout()
        flowLayout.itemSize = itemSize
        flowLayout.minimumInteritemSpacing = 18
        flowLayout.minimumLineSpacing = 24
        flowLayout.sectionInset = NSEdgeInsets(top: 16, left: 24, bottom: contentBottomInset, right: 24)
        flowLayout.sectionHeadersPinToVisibleBounds = false

        let collectionView = NSCollectionView()
        collectionView.collectionViewLayout = flowLayout
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = true
        collectionView.backgroundColors = [.clear]

        collectionView.register(
            LibraryCardItemCell.self,
            forItemWithIdentifier: NSUserInterfaceItemIdentifier("LibraryCardItemCell")
        )
        collectionView.register(
            LibraryGridHeaderSupplementaryView.self,
            forSupplementaryViewOfKind: NSCollectionView.elementKindSectionHeader,
            withIdentifier: NSUserInterfaceItemIdentifier("LibraryGridHeaderView")
        )

        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator

        scrollView.documentView = collectionView
        context.coordinator.collectionView = collectionView
        context.coordinator.flowLayout = flowLayout
        context.coordinator.updateHeaderIfNeeded()
        context.coordinator.bindDataSource()

        return scrollView
    }

    public func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSScrollView, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions()
    }

    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updateHeaderIfNeeded()
        context.coordinator.bindDataSource()
        context.coordinator.applyUpdatePlan()
    }

    // MARK: - Coordinator

    @MainActor
    public final class Coordinator: NSObject, NSCollectionViewDataSource, NSCollectionViewDelegateFlowLayout {
        var parent: LibraryGridSurface<Header>
        weak var collectionView: NSCollectionView?
        weak var flowLayout: NSCollectionViewFlowLayout?

        private var lastAppliedRevision: UInt64 = 0
        private var lastTotalCount: Int = 0
        private var lastPlayingID: String? = nil
        private var lastSelection: Set<String> = []

        var headerHostingView: NSHostingView<AnyView>?
        private var lastHeaderHeight: CGFloat = 0

        init(parent: LibraryGridSurface<Header>) {
            self.parent = parent
        }

        func updateHeaderIfNeeded() {
            if parent.hasHeader, let headerContent = parent.headerContent {
                let anyHeader = AnyView(headerContent)
                if let headerHostingView {
                    headerHostingView.rootView = anyHeader
                } else {
                    let host = NSHostingView(rootView: anyHeader)
                    self.headerHostingView = host
                }
            } else {
                headerHostingView = nil
            }
        }

        func bindDataSource() {
            if let pagedDS = parent.dataSource as? PagedQueryResultGridDataSource {
                pagedDS.onPageLoaded = { [weak self] (indices: IndexSet) in
                    guard let self, let cv = self.collectionView else { return }
                    let indexPaths = indices.map { IndexPath(item: $0, section: 0) }
                    cv.reloadItems(at: Set(indexPaths))
                }
            }
        }

        func applyUpdatePlan() {
            guard let collectionView else { return }

            if flowLayout?.itemSize != parent.itemSize {
                flowLayout?.itemSize = parent.itemSize
                collectionView.collectionViewLayout?.invalidateLayout()
            }

            if flowLayout?.sectionInset.bottom != parent.contentBottomInset {
                flowLayout?.sectionInset = NSEdgeInsets(top: 16, left: 24, bottom: parent.contentBottomInset, right: 24)
            }

            if parent.hasHeader, let host = headerHostingView {
                let currentHeight = host.fittingSize.height
                if abs(currentHeight - lastHeaderHeight) > 1 {
                    lastHeaderHeight = currentHeight
                    flowLayout?.invalidateLayout()
                }
            }

            let currentCount = parent.dataSource.totalCount

            // 1. Revision / Structure change
            if parent.revision != lastAppliedRevision || currentCount != lastTotalCount {
                lastAppliedRevision = parent.revision
                lastTotalCount = currentCount
                lastPlayingID = parent.playingTrackID
                lastSelection = parent.selectedIDs

                collectionView.reloadData()
                return
            }

            // 2. Playback Identity change
            if parent.playingTrackID != lastPlayingID {
                lastPlayingID = parent.playingTrackID

                let visibleIndexPaths = collectionView.indexPathsForVisibleItems()
                var toReload = Set<IndexPath>()
                for ip in visibleIndexPaths {
                    if let item = parent.dataSource.item(at: ip.item) {
                        if item.id == parent.playingTrackID || item.id == lastPlayingID {
                            toReload.insert(ip)
                        }
                    }
                }
                if !toReload.isEmpty {
                    collectionView.reloadItems(at: toReload)
                }
            }

            // 3. Selection change only
            if parent.selectedIDs != lastSelection {
                lastSelection = parent.selectedIDs
                let visibleIndexPaths = collectionView.indexPathsForVisibleItems()
                for ip in visibleIndexPaths {
                    if let cell = collectionView.item(at: ip) as? LibraryCardItemCell,
                       let item = parent.dataSource.item(at: ip.item) {
                        cell.updateSelectionState(isSelected: parent.selectedIDs.contains(item.id))
                    }
                }
            }

            // 4. Otherwise: NO-OP! Zero O(N) work performed.
        }

        // MARK: - NSCollectionViewDataSource

        public func numberOfSections(in collectionView: NSCollectionView) -> Int {
            1
        }

        public func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
            parent.dataSource.totalCount
        }

        public func collectionView(
            _ collectionView: NSCollectionView,
            itemForRepresentedObjectAt indexPath: IndexPath
        ) -> NSCollectionViewItem {
            let item = collectionView.makeItem(
                withIdentifier: NSUserInterfaceItemIdentifier("LibraryCardItemCell"),
                for: indexPath
            )

            guard let cell = item as? LibraryCardItemCell else {
                return item
            }

            let maybeData = parent.dataSource.item(at: indexPath.item)
            let isCurrent = (maybeData?.id == parent.playingTrackID)
            let isSelected = maybeData.map { parent.selectedIDs.contains($0.id) } ?? false

            cell.configure(
                summary: maybeData,
                isCurrent: isCurrent,
                isPlaying: parent.isPlaying && isCurrent,
                isSelected: isSelected,
                delegate: parent.delegate
            )

            // Prefetch nearby artwork
            if maybeData?.artworkReference != nil, indexPath.item % 15 == 0 {
                parent.dataSource.prefetch(range: max(0, indexPath.item - 10)..<min(parent.dataSource.totalCount, indexPath.item + 30))
            }

            return cell
        }

        public func collectionView(
            _ collectionView: NSCollectionView,
            viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind,
            at indexPath: IndexPath
        ) -> NSView {
            if kind == NSCollectionView.elementKindSectionHeader {
                let view = collectionView.makeSupplementaryView(
                    ofKind: kind,
                    withIdentifier: NSUserInterfaceItemIdentifier("LibraryGridHeaderView"),
                    for: indexPath
                )
                if let headerView = view as? LibraryGridHeaderSupplementaryView {
                    headerView.attachHostView(headerHostingView)
                }
                return view
            }
            return NSView()
        }

        // MARK: - NSCollectionViewDelegateFlowLayout

        public func collectionView(
            _ collectionView: NSCollectionView,
            layout collectionViewLayout: NSCollectionViewLayout,
            referenceSizeForHeaderInSection section: Int
        ) -> NSSize {
            guard parent.hasHeader, let host = headerHostingView else {
                return .zero
            }
            let width = max(collectionView.bounds.width, 300)
            host.frame = NSRect(x: 0, y: 0, width: width, height: 0)
            let height = host.fittingSize.height
            lastHeaderHeight = height
            return NSSize(width: width, height: max(height, 1))
        }

        // MARK: - NSCollectionViewDelegate

        public func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
            var selected = Set<String>()
            for ip in collectionView.selectionIndexPaths {
                if let data = parent.dataSource.item(at: ip.item) {
                    selected.insert(data.id)
                }
            }
            lastSelection = selected
            parent.delegate?.surfaceDidSelect(ids: selected)
        }

        public func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
            var selected = Set<String>()
            for ip in collectionView.selectionIndexPaths {
                if let data = parent.dataSource.item(at: ip.item) {
                    selected.insert(data.id)
                }
            }
            lastSelection = selected
            parent.delegate?.surfaceDidSelect(ids: selected)
        }
    }
}

extension LibraryGridSurface where Header == EmptyView {
    public init(
        revision: UInt64,
        dataSource: any LibraryCardDataSource,
        selectedIDs: Set<String> = [],
        playingTrackID: String? = nil,
        isPlaying: Bool = false,
        itemSize: CGSize = CGSize(width: 170, height: 236),
        contentBottomInset: CGFloat = 100,
        delegate: (any LibrarySurfaceDelegate)? = nil
    ) {
        self.revision = revision
        self.dataSource = dataSource
        self.selectedIDs = selectedIDs
        self.playingTrackID = playingTrackID
        self.isPlaying = isPlaying
        self.itemSize = itemSize
        self.contentBottomInset = contentBottomInset
        self.delegate = delegate
        self.headerContent = nil
    }

    public init(
        revision: UInt64,
        items: [LibraryCardSummary],
        selectedIDs: Set<String> = [],
        playingTrackID: String? = nil,
        isPlaying: Bool = false,
        itemSize: CGSize = CGSize(width: 170, height: 236),
        contentBottomInset: CGFloat = 100,
        delegate: (any LibrarySurfaceDelegate)? = nil
    ) {
        self.init(
            revision: revision,
            dataSource: ArrayLibraryCardDataSource(items: items),
            selectedIDs: selectedIDs,
            playingTrackID: playingTrackID,
            isPlaying: isPlaying,
            itemSize: itemSize,
            contentBottomInset: contentBottomInset,
            delegate: delegate
        )
    }
}

// MARK: - Header Supplementary View

public final class LibraryGridHeaderSupplementaryView: NSView {
    private weak var currentHost: NSView?

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    public func attachHostView(_ host: NSView?) {
        guard let host else { return }
        if currentHost !== host {
            currentHost?.removeFromSuperview()
            currentHost = host
            host.translatesAutoresizingMaskIntoConstraints = false
            addSubview(host)
            NSLayoutConstraint.activate([
                host.topAnchor.constraint(equalTo: topAnchor),
                host.bottomAnchor.constraint(equalTo: bottomAnchor),
                host.leadingAnchor.constraint(equalTo: leadingAnchor),
                host.trailingAnchor.constraint(equalTo: trailingAnchor)
            ])
        }
    }
}

// MARK: - High-Performance Pure AppKit Card Cell

public final class LibraryCardItemCell: NSCollectionViewItem {
    
    private let artworkContainer = NSView()
    private let artworkImageView = NSImageView()
    private let placeholderImageView = NSImageView()
    private let badgeContainer = NSView()
    private let badgeLabel = NSTextField(labelWithString: "")
    private let playButton = NSButton()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let secondaryLabel = NSTextField(labelWithString: "")
    
    private var currentSummary: LibraryCardSummary?
    private weak var currentDelegate: (any LibrarySurfaceDelegate)?
    private var isHovered: Bool = false
    private var isCurrentPlaying: Bool = false
    private var loadArtworkTask: Task<Void, Never>?
    
    public override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nil, bundle: nil)
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    public override func loadView() {
        let rootView = CardRootView()
        rootView.wantsLayer = true
        rootView.cell = self
        self.view = rootView
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
    }
    
    private func setupViews() {
        // Artwork Container
        artworkContainer.wantsLayer = true
        artworkContainer.layer?.cornerRadius = 10
        artworkContainer.layer?.masksToBounds = true
        artworkContainer.layer?.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.25).cgColor
        artworkContainer.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.2).cgColor
        artworkContainer.layer?.borderWidth = 0.5
        view.addSubview(artworkContainer)
        
        // Artwork Image View
        artworkImageView.imageScaling = .scaleProportionallyUpOrDown
        artworkImageView.wantsLayer = true
        artworkContainer.addSubview(artworkImageView)
        
        // Placeholder Image View
        placeholderImageView.imageScaling = .scaleProportionallyDown
        placeholderImageView.contentTintColor = .tertiaryLabelColor
        artworkContainer.addSubview(placeholderImageView)
        
        // Badge Container & Label
        badgeContainer.wantsLayer = true
        badgeContainer.layer?.cornerRadius = 4
        badgeContainer.layer?.masksToBounds = true
        badgeContainer.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.6).cgColor
        badgeContainer.isHidden = true
        artworkContainer.addSubview(badgeContainer)
        
        badgeLabel.font = .systemFont(ofSize: 9, weight: .bold)
        badgeLabel.textColor = .white
        badgeLabel.alignment = .center
        badgeLabel.isBezeled = false
        badgeLabel.drawsBackground = false
        badgeLabel.isEditable = false
        badgeContainer.addSubview(badgeLabel)
        
        // Play Button Overlay
        playButton.bezelStyle = .circular
        playButton.title = ""
        playButton.isBordered = false
        playButton.wantsLayer = true
        playButton.layer?.cornerRadius = 18
        playButton.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        playButton.layer?.shadowColor = NSColor.black.cgColor
        playButton.layer?.shadowOpacity = 0.3
        playButton.layer?.shadowRadius = 4
        playButton.layer?.shadowOffset = CGSize(width: 0, height: -2)
        playButton.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")?.withSymbolConfiguration(.init(pointSize: 13, weight: .semibold))
        playButton.contentTintColor = .white
        playButton.target = self
        playButton.action = #selector(handlePlayClicked)
        playButton.alphaValue = 0
        artworkContainer.addSubview(playButton)
        
        // Labels
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        titleLabel.isBezeled = false
        titleLabel.drawsBackground = false
        titleLabel.isEditable = false
        view.addSubview(titleLabel)
        
        subtitleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.maximumNumberOfLines = 1
        subtitleLabel.isBezeled = false
        subtitleLabel.drawsBackground = false
        subtitleLabel.isEditable = false
        view.addSubview(subtitleLabel)
        
        secondaryLabel.font = .systemFont(ofSize: 11, weight: .regular)
        secondaryLabel.textColor = .tertiaryLabelColor
        secondaryLabel.lineBreakMode = .byTruncatingTail
        secondaryLabel.maximumNumberOfLines = 1
        secondaryLabel.isBezeled = false
        secondaryLabel.drawsBackground = false
        secondaryLabel.isEditable = false
        view.addSubview(secondaryLabel)
    }
    
    public override func viewDidLayout() {
        super.viewDidLayout()
        layoutCardComponents()
    }
    
    private func layoutCardComponents() {
        let bounds = view.bounds
        guard bounds.width > 0 && bounds.height > 0 else { return }
        
        let artWidth = bounds.width
        let artHeight = bounds.width // 1:1 Aspect ratio for artwork
        
        // Coordinates in AppKit: (0,0) is bottom-left
        let secHeight: CGFloat = 14
        let subHeight: CGFloat = 16
        let titleHeight: CGFloat = 18
        let spacing: CGFloat = 3
        
        let artOriginY = bounds.height - artHeight
        artworkContainer.frame = CGRect(x: 0, y: artOriginY, width: artWidth, height: artHeight)
        artworkImageView.frame = artworkContainer.bounds
        
        let iconSize: CGFloat = min(48, artWidth * 0.3)
        placeholderImageView.frame = CGRect(
            x: (artWidth - iconSize) / 2,
            y: (artHeight - iconSize) / 2,
            width: iconSize,
            height: iconSize
        )
        
        // Play button bottom-right inside artworkContainer
        let playBtnSize: CGFloat = 36
        playButton.frame = CGRect(
            x: artWidth - playBtnSize - 8,
            y: 8,
            width: playBtnSize,
            height: playBtnSize
        )
        
        // Badge top-left inside artworkContainer
        if !badgeContainer.isHidden {
            let badgeTextSize = badgeLabel.attributedStringValue.size()
            let badgeW = badgeTextSize.width + 10
            let badgeH: CGFloat = 16
            badgeContainer.frame = CGRect(x: 8, y: artHeight - badgeH - 8, width: badgeW, height: badgeH)
            badgeLabel.frame = badgeContainer.bounds
        }
        
        // Labels underneath
        let titleY = artOriginY - titleHeight - 6
        titleLabel.frame = CGRect(x: 2, y: titleY, width: artWidth - 4, height: titleHeight)
        
        let subY = titleY - subHeight - spacing
        subtitleLabel.frame = CGRect(x: 2, y: subY, width: artWidth - 4, height: subHeight)
        
        let secY = subY - secHeight - spacing
        secondaryLabel.frame = CGRect(x: 2, y: secY, width: artWidth - 4, height: secHeight)
    }
    
    public override func prepareForReuse() {
        super.prepareForReuse()
        loadArtworkTask?.cancel()
        loadArtworkTask = nil
        artworkImageView.image = nil
        placeholderImageView.isHidden = false
        badgeContainer.isHidden = true
        isHovered = false
        isCurrentPlaying = false
        playButton.alphaValue = 0
        artworkContainer.layer?.borderWidth = 0.5
        artworkContainer.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.2).cgColor
    }
    
    public func configure(
        summary: LibraryCardSummary?,
        isCurrent: Bool,
        isPlaying: Bool,
        isSelected: Bool,
        delegate: (any LibrarySurfaceDelegate)?
    ) {
        self.currentSummary = summary
        self.currentDelegate = delegate
        self.isCurrentPlaying = isPlaying
        
        guard let item = summary else {
            titleLabel.stringValue = "..."
            subtitleLabel.stringValue = ""
            secondaryLabel.stringValue = ""
            return
        }
        
        titleLabel.stringValue = item.title
        titleLabel.textColor = isCurrent ? .controlAccentColor : .labelColor
        
        subtitleLabel.stringValue = item.subtitle
        secondaryLabel.stringValue = item.secondaryText ?? (item.durationText ?? "")
        
        if let badge = item.badgeText, !badge.isEmpty {
            badgeContainer.isHidden = false
            badgeLabel.stringValue = badge
        } else {
            badgeContainer.isHidden = true
        }
        
        // Circular or rounded
        if item.isCircularArtwork {
            let radius = view.bounds.width / 2
            artworkContainer.layer?.cornerRadius = radius > 0 ? radius : 10
            placeholderImageView.image = NSImage(systemSymbolName: "music.mic", accessibilityDescription: nil)
        } else {
            artworkContainer.layer?.cornerRadius = 10
            placeholderImageView.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)
        }
        
        updateSelectionState(isSelected: isSelected)
        updatePlayButtonState()
        
        // Load thumbnail asynchronously
        if let ref = item.artworkReference, !ref.isEmpty {
            loadArtworkTask?.cancel()
            weak var targetImageView = self.artworkImageView
            weak var targetPlaceholder = self.placeholderImageView
            loadArtworkTask = Task { @MainActor [ref] in
                let img = await ArtworkLoader.shared.loadThumbnail(for: ref, bucket: .px512)
                guard !Task.isCancelled else { return }
                if let img, let targetImageView {
                    targetImageView.image = img
                    targetPlaceholder?.isHidden = true
                }
            }
        } else {
            artworkImageView.image = nil
            placeholderImageView.isHidden = false
        }
        
        layoutCardComponents()
    }
    
    public func updateSelectionState(isSelected: Bool) {
        if isSelected {
            artworkContainer.layer?.borderColor = NSColor.controlAccentColor.cgColor
            artworkContainer.layer?.borderWidth = 2.5
        } else {
            artworkContainer.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.2).cgColor
            artworkContainer.layer?.borderWidth = 0.5
        }
    }
    
    private func updatePlayButtonState() {
        let shouldShow = isHovered || isCurrentPlaying
        playButton.animator().alphaValue = shouldShow ? 1.0 : 0.0
        let iconName = isCurrentPlaying ? "pause.fill" : "play.fill"
        playButton.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .semibold))
    }
    
    @objc private func handlePlayClicked() {
        guard let id = currentSummary?.id else { return }
        currentDelegate?.surfaceDidActivate(id: id)
    }
    
    // MARK: - Hover & Menu
    
    func handleMouseEnter() {
        isHovered = true
        updatePlayButtonState()
    }
    
    func handleMouseExit() {
        isHovered = false
        updatePlayButtonState()
    }
    
    func handleDoubleClick() {
        guard let id = currentSummary?.id else { return }
        currentDelegate?.surfaceDidActivate(id: id)
    }
    
    func menuForEvent(_ event: NSEvent) -> NSMenu? {
        guard let id = currentSummary?.id else { return nil }
        return currentDelegate?.surfaceDidRequestContextMenu(forID: id, event: event)
    }
    
    deinit {
        loadArtworkTask?.cancel()
    }
    
    // MARK: - Root View for Custom Mouse Events & Menus
    
    private final class CardRootView: NSView {
        weak var cell: LibraryCardItemCell?
        private var trackingAreaRef: NSTrackingArea?
        
        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let existing = trackingAreaRef {
                removeTrackingArea(existing)
            }
            let area = NSTrackingArea(
                rect: bounds,
                options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(area)
            self.trackingAreaRef = area
        }
        
        override func mouseEntered(with event: NSEvent) {
            cell?.handleMouseEnter()
        }
        
        override func mouseExited(with event: NSEvent) {
            cell?.handleMouseExit()
        }
        
        override func menu(for event: NSEvent) -> NSMenu? {
            if let menu = cell?.menuForEvent(event) {
                return menu
            }
            return super.menu(for: event)
        }
        
        override func mouseDown(with event: NSEvent) {
            if event.clickCount == 2 {
                cell?.handleDoubleClick()
                return
            }
            super.mouseDown(with: event)
        }
    }
}
#endif


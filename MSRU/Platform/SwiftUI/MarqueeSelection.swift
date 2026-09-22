//
//  MarqueeSelection.swift
//  MSRU
//
//  Rubber-band marquee selection container and modifier-aware item selection for SwiftUI macOS.
//

import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Item Frame Preference Key

public struct MarqueeItemFramePreferenceKey: PreferenceKey {
    public static var defaultValue: [AnyHashable: CGRect] = [:]

    public static func reduce(value: inout [AnyHashable: CGRect], nextValue: () -> [AnyHashable: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

// MARK: - Marquee Item Modifier

public extension View {
    func marqueeItem<ID: Hashable & Sendable>(id: ID, spaceName: String = "MarqueeSelectionSpace") -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: MarqueeItemFramePreferenceKey.self,
                    value: [AnyHashable(id): geo.frame(in: .named(spaceName))]
                )
            }
        )
    }
}

// MARK: - Selection Helper

public enum SelectionHelper {
    public static func handleTap<ID: Hashable & Sendable>(
        clickedID: ID,
        allIDs: [ID],
        selection: inout Set<ID>
    ) {
        #if canImport(AppKit)
        let flags = NSEvent.modifierFlags
        if flags.contains(.command) {
            if selection.contains(clickedID) {
                selection.remove(clickedID)
            } else {
                selection.insert(clickedID)
            }
            return
        }

        if flags.contains(.shift), let firstSelected = selection.first,
           let fromIdx = allIDs.firstIndex(of: firstSelected),
           let toIdx = allIDs.firstIndex(of: clickedID) {
            let range = min(fromIdx, toIdx)...max(fromIdx, toIdx)
            for idx in range {
                selection.insert(allIDs[idx])
            }
            return
        }
        #endif

        selection = [clickedID]
    }

    public static func handleTap<ID: Hashable & Sendable>(
        for clickedID: ID,
        selectedIDs: Binding<Set<ID>>,
        allIDs: [ID]
    ) {
        var current = selectedIDs.wrappedValue
        handleTap(clickedID: clickedID, allIDs: allIDs, selection: &current)
        selectedIDs.wrappedValue = current
    }
}

// MARK: - Marquee Selection Container

public struct MarqueeSelectionContainer<Content: View, ID: Hashable & Sendable>: View {
    @Binding var selection: Set<ID>
    let allIDs: [ID]
    let spaceName: String
    let onDeselectAll: (() -> Void)?
    @ViewBuilder let content: Content

    @State private var itemFrames: [AnyHashable: CGRect] = [:]
    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?
    @State private var initialSelection: Set<ID> = []

    public init(
        selection: Binding<Set<ID>>,
        allIDs: [ID] = [],
        spaceName: String = "MarqueeSelectionSpace",
        onDeselectAll: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self._selection = selection
        self.allIDs = allIDs
        self.spaceName = spaceName
        self.onDeselectAll = onDeselectAll
        self.content = content()
    }

    public init(
        selectedIDs: Binding<Set<ID>>,
        allIDs: [ID] = [],
        spaceName: String = "MarqueeSelectionSpace",
        onDeselectAll: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self._selection = selectedIDs
        self.allIDs = allIDs
        self.spaceName = spaceName
        self.onDeselectAll = onDeselectAll
        self.content = content()
    }

    private var marqueeRect: CGRect? {
        guard let start = dragStart, let current = dragCurrent else { return nil }
        let minX = min(start.x, current.x)
        let minY = min(start.y, current.y)
        let width = abs(current.x - start.x)
        let height = abs(current.y - start.y)
        guard width > 3 || height > 3 else { return nil }
        return CGRect(x: minX, y: minY, width: width, height: height)
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            content
                .coordinateSpace(name: spaceName)
                .onPreferenceChange(MarqueeItemFramePreferenceKey.self) { frames in
                    self.itemFrames = frames
                }

            // Visual Marquee Rubber-Band Box
            if let rect = marqueeRect {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.accentColor.opacity(0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .strokeBorder(Color.accentColor.opacity(0.8), lineWidth: 1)
                    )
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .allowsHitTesting(false)
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 4, coordinateSpace: .named(spaceName))
                .onChanged { value in
                    if dragStart == nil {
                        dragStart = value.startLocation
                        initialSelection = selection
                    }
                    dragCurrent = value.location

                    guard let rect = marqueeRect else { return }

                    var hitIDs = Set<ID>()
                    for (anyID, frame) in itemFrames {
                        if rect.intersects(frame), let typedID = anyID.base as? ID {
                            hitIDs.insert(typedID)
                        }
                    }

                    #if canImport(AppKit)
                    let flags = NSEvent.modifierFlags
                    if flags.contains(.command) || flags.contains(.shift) {
                        selection = initialSelection.union(hitIDs)
                    } else {
                        selection = hitIDs
                    }
                    #else
                    selection = hitIDs
                    #endif
                }
                .onEnded { _ in
                    dragStart = nil
                    dragCurrent = nil
                }
        )
    }
}

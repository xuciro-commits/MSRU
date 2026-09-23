//
//  SourceFilterBarView.swift
//  MSRU
//
//  Capsule-style source filter bar for scoping queries in Albums, Songs, and Artists views.
//  Implements Option A: segmented capsule picker scrolling naturally with content.
//

import SwiftUI
import AppFoundation

public struct SourceFilterBarView: View {
    public let sources: [SourceFilterItem]
    @Binding public var selectedSourceID: String?
    public var onSelect: ((String?) -> Void)?

    public init(
        sources: [SourceFilterItem],
        selectedSourceID: Binding<String?>,
        onSelect: ((String?) -> Void)? = nil
    ) {
        self.sources = sources
        self._selectedSourceID = selectedSourceID
        self.onSelect = onSelect
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(sources) { item in
                    let isSelected = (selectedSourceID == item.sourceID)

                    Button {
                        selectedSourceID = item.sourceID
                        onSelect?(item.sourceID)
                    } label: {
                        HStack(spacing: 6) {
                            if item.sourceID == nil {
                                Image(systemName: "square.grid.2x2")
                                    .font(.caption2)
                            } else if SourceID.isLocalSourceID(item.sourceID) {
                                Image(systemName: "internaldrive")
                                    .font(.caption2)
                            } else {
                                Image(systemName: "server.rack")
                                    .font(.caption2)
                            }

                            Text(item.displayName)
                                .font(.callout.weight(isSelected ? .semibold : .regular))

                            if let count = item.count {
                                Text("\(count)")
                                    .font(.caption.monospacedDigit())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(isSelected ? Color.white.opacity(0.2) : Color.primary.opacity(0.08))
                                    )
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.08))
                        )
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Capsule())
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Preview

#Preview("Source Filter Bar") {
    @Previewable @State var selected: String? = nil
    let items = [
        SourceFilterItem(id: nil, displayName: "All", count: nil),
        SourceFilterItem(id: "local", displayName: "Local Files", count: 96),
        SourceFilterItem(id: "src_subsonic_1", displayName: "极空间 NAS (msru)", count: nil)
    ]

    VStack(alignment: .leading, spacing: 20) {
        SourceFilterBarView(sources: items, selectedSourceID: $selected)
        Text("Selected Source: \(selected ?? "All")")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    .padding()
    .frame(width: 500)
}

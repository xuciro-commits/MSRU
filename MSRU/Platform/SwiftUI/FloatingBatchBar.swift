//
//  FloatingBatchBar.swift
//  MSRU
//
//  Floating Liquid Glass batch action bar displayed above MiniPlayerBar when multiple items are selected.
//

import SwiftUI

public struct FloatingBatchBar<Actions: View>: View {
    public let count: Int
    public let title: String
    public let onDeselect: () -> Void
    @ViewBuilder public let actions: Actions

    public init(
        count: Int,
        title: String,
        onDeselect: @escaping () -> Void,
        @ViewBuilder actions: () -> Actions
    ) {
        self.count = count
        self.title = title
        self.onDeselect = onDeselect
        self.actions = actions()
    }

    public var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.accentColor)

            Text(title)
                .font(.callout.weight(.medium))

            Spacer()

            actions

            Button(LocalizedStringKey("Deselect")) {
                onDeselect()
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 24)
        .padding(.bottom, 90)
    }
}

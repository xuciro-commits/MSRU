//
//  ContinuousShelfView.swift
//  MSRU
//
//  Apple Music-styled edge-to-edge continuous horizontal shelf.
//  Extends under sidebar and inspector panels without edge clipping,
//  with floating translucent pagination chevrons (< and >).
//

import SwiftUI
import AppFoundationUI

// MARK: - Generic Collection Continuous Shelf

public struct ContinuousShelfView<Item: Identifiable, CardContent: View>: View {
    public let title: String
    public let subtitle: String?
    public let hasChevronHeader: Bool
    public let onTitleTap: (() -> Void)?
    public let items: [Item]
    public let spacing: CGFloat
    public let leadingInset: CGFloat
    public let pageSize: Int
    @ViewBuilder public let cardContent: (Item) -> CardContent

    @State private var currentIndex: Int = 0
    @State private var isHovering: Bool = false

    public init(
        title: String,
        subtitle: String? = nil,
        hasChevronHeader: Bool = false,
        onTitleTap: (() -> Void)? = nil,
        items: [Item],
        spacing: CGFloat = 16,
        leadingInset: CGFloat = 28,
        pageSize: Int = 3,
        @ViewBuilder cardContent: @escaping (Item) -> CardContent
    ) {
        self.title = title
        self.subtitle = subtitle
        self.hasChevronHeader = hasChevronHeader
        self.onTitleTap = onTitleTap
        self.items = items
        self.spacing = spacing
        self.leadingInset = leadingInset
        self.pageSize = pageSize
        self.cardContent = cardContent
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerView
                .padding(.horizontal, leadingInset)

            ScrollViewReader { proxy in
                ZStack {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: spacing) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                cardContent(item)
                                    .id(index)
                            }
                        }
                        .padding(.horizontal, leadingInset)
                        .padding(.vertical, 6)
                    }
                    .hideScrollIndicatorsCompletely()

                    // Floating Navigation Buttons (< and >)
                    navigationControls(proxy: proxy)
                }
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Button {
                onTitleTap?()
            } label: {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.title2.bold())
                        .foregroundStyle(.primary)

                    if hasChevronHeader {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(onTitleTap == nil)

            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Navigation Buttons

    @ViewBuilder
    private func navigationControls(proxy: ScrollViewProxy) -> some View {
        let canGoBack = currentIndex > 0
        let canGoForward = currentIndex + pageSize < items.count

        HStack {
            if canGoBack && isHovering {
                Button {
                    let target = max(currentIndex - pageSize, 0)
                    currentIndex = target
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                        proxy.scrollTo(target, anchor: .leading)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.8))
                        .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
            } else {
                Spacer().frame(width: 34)
            }

            Spacer()

            if canGoForward && (isHovering || currentIndex == 0) {
                Button {
                    let target = min(currentIndex + pageSize, max(items.count - 1, 0))
                    currentIndex = target
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                        proxy.scrollTo(target, anchor: .leading)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.8))
                        .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
            } else {
                Spacer().frame(width: 34)
            }
        }
        .padding(.horizontal, 4)
        .allowsHitTesting(true)
    }
}

// MARK: - ViewBuilder Shelf Container (for custom content or raw cards)

public struct ContinuousShelfContainer<Content: View>: View {
    public let title: String
    public let subtitle: String?
    public let hasChevronHeader: Bool
    public let onTitleTap: (() -> Void)?
    public let leadingInset: CGFloat
    @ViewBuilder public let content: () -> Content

    public init(
        title: String,
        subtitle: String? = nil,
        hasChevronHeader: Bool = false,
        onTitleTap: (() -> Void)? = nil,
        leadingInset: CGFloat = 28,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.hasChevronHeader = hasChevronHeader
        self.onTitleTap = onTitleTap
        self.leadingInset = leadingInset
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Button {
                    onTitleTap?()
                } label: {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.title2.bold())
                            .foregroundStyle(.primary)

                        if hasChevronHeader {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(onTitleTap == nil)

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, leadingInset)

            ScrollView(.horizontal, showsIndicators: false) {
                content()
                    .padding(.horizontal, leadingInset)
                    .padding(.vertical, 6)
            }
            .hideScrollIndicatorsCompletely()
        }
    }
}

// MARK: - Preview

private struct ShelfPreviewItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let color: Color
}

#Preview("Continuous Shelf") {
    let items = [
        ShelfPreviewItem(id: "1", title: "Adele 21", subtitle: "Adele", color: .purple),
        ShelfPreviewItem(id: "2", title: "Apple Music 1", subtitle: "Apple Music Radio", color: .red),
        ShelfPreviewItem(id: "3", title: "Kim Petras", subtitle: "Radio Takeover", color: .blue),
        ShelfPreviewItem(id: "4", title: "Top 25: Washington", subtitle: "Apple Music", color: .green),
        ShelfPreviewItem(id: "5", title: "Top 100: Japan", subtitle: "Apple Music", color: .orange),
        ShelfPreviewItem(id: "6", title: "Max Styler", subtitle: "Club Mix 008", color: .cyan)
    ]

    ContinuousShelfView(
        title: "Recently Played",
        hasChevronHeader: true,
        items: items
    ) { item in
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(item.color.gradient)
                .frame(width: 160, height: 160)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 160, alignment: .leading)
        }
    }
    .frame(width: 800, height: 300)
    .background(Color.black.opacity(0.9))
}

#Preview("Continuous Shelf Container") {
    ContinuousShelfContainer(
        title: "Apple Music Sessions",
        hasChevronHeader: true
    ) {
        HStack(spacing: 16) {
            ForEach(1...5, id: \.self) { index in
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 180, height: 180)
                    Text("Session \(index)")
                        .font(.headline)
                }
            }
        }
    }
    .frame(width: 800, height: 300)
}


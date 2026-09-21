//
//  ArtworkThumbnailView.swift
//  MSRU
//
//  Created for Declarative On-Demand Thumbnail Loading in SwiftUI Lists and Grids.
//

import SwiftUI

public struct ArtworkThumbnailView: View {

    public let reference: String?
    /// Pixel dimensions used strictly for background decode and downsampling (default: 240x240).
    public let thumbnailPixelSize: CGSize
    /// Explicit SwiftUI layout frame size. If nil, the view is flexible and adapts to parent layout with aspect ratio 1:1.
    public let layoutSize: CGSize?
    public let placeholderSystemImage: String
    public let cornerRadius: CGFloat
    public let isCircular: Bool

    @State private var loadedImage: PlatformImage? = nil

    public init(
        reference: String?,
        thumbnailPixelSize: CGSize = CGSize(width: 240, height: 240),
        layoutSize: CGSize? = nil,
        placeholderSystemImage: String = "music.note",
        cornerRadius: CGFloat = 8,
        isCircular: Bool = false
    ) {
        self.reference = reference
        self.thumbnailPixelSize = thumbnailPixelSize
        self.layoutSize = layoutSize
        self.placeholderSystemImage = placeholderSystemImage
        self.cornerRadius = cornerRadius
        self.isCircular = isCircular
    }

    /// Convenience init for fixed-size thumbnail displays (e.g. Table rows).
    public init(
        reference: String?,
        fixedSize: CGSize,
        thumbnailPixelSize: CGSize? = nil,
        placeholderSystemImage: String = "music.note",
        cornerRadius: CGFloat = 6,
        isCircular: Bool = false
    ) {
        self.reference = reference
        self.thumbnailPixelSize = thumbnailPixelSize ?? CGSize(width: fixedSize.width * 2, height: fixedSize.height * 2)
        self.layoutSize = fixedSize
        self.placeholderSystemImage = placeholderSystemImage
        self.cornerRadius = cornerRadius
        self.isCircular = isCircular
    }

    public var body: some View {
        Group {
            if isCircular {
                imageContent
                    .aspectRatio(1.0, contentMode: .fit)
                    .clipShape(Circle())
            } else {
                imageContent
                    .aspectRatio(1.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        }
        .modifier(LayoutFrameModifier(layoutSize: layoutSize))
        .task(id: reference) {
            guard let reference, !reference.isEmpty else {
                loadedImage = nil
                return
            }
            let image = await ArtworkLoader.shared.loadThumbnail(for: reference, targetSize: thumbnailPixelSize)
            if !Task.isCancelled {
                loadedImage = image
            }
        }
    }

    @ViewBuilder
    private var imageContent: some View {
        if let image = loadedImage {
            #if canImport(AppKit)
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
            #elseif canImport(UIKit)
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
            #endif
        } else {
            placeholderView
        }
    }

    private var placeholderView: some View {
        ZStack {
            if isCircular {
                Circle()
                    .fill(Color.secondary.opacity(0.12))
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
            }
            Image(systemName: placeholderSystemImage)
                .font(.system(size: (layoutSize.map { min($0.width, $0.height) } ?? 48) * 0.45))
                .foregroundStyle(.secondary.opacity(0.6))
        }
    }
}

private struct LayoutFrameModifier: ViewModifier {
    let layoutSize: CGSize?

    func body(content: Content) -> some View {
        if let layoutSize {
            content.frame(width: layoutSize.width, height: layoutSize.height)
        } else {
            content
        }
    }
}

//
//  ArtworkThumbnailView.swift
//  MSRU
//
//  Declarative on-demand image loading view (MediaImageView / ArtworkThumbnailView)
//  with automatic pixel-bucket downsampling, L1/L2/L3 3-tier caching, and fallback placeholders.
//

import SwiftUI

public typealias MediaImageView = ArtworkThumbnailView

public struct ArtworkThumbnailView: View {

    public let mediaReference: MediaImageReference?
    /// Explicit SwiftUI layout frame size. If nil, the view is flexible and adapts to parent layout with aspect ratio 1:1.
    public let layoutSize: CGSize?
    /// Pixel dimensions used strictly for background decode and downsampling.
    public let thumbnailPixelSize: CGSize
    public let placeholderSystemImage: String
    public let cornerRadius: CGFloat
    public let isCircular: Bool

    @State private var loadedImage: PlatformImage? = nil

    private static func initialCachedImage(for reference: MediaImageReference?, targetSize: CGSize) -> PlatformImage? {
        guard let reference else { return nil }
        return MediaImagePipeline.shared.cachedThumbnail(for: reference, targetSize: targetSize)
    }

    // MARK: - Initializers

    public init(
        reference: MediaImageReference?,
        thumbnailPixelSize: CGSize = CGSize(width: 256, height: 256),
        layoutSize: CGSize? = nil,
        placeholderSystemImage: String = "music.note",
        cornerRadius: CGFloat = 8,
        isCircular: Bool = false
    ) {
        self.mediaReference = reference
        self.thumbnailPixelSize = thumbnailPixelSize
        self.layoutSize = layoutSize
        self.placeholderSystemImage = placeholderSystemImage
        self.cornerRadius = cornerRadius
        self.isCircular = isCircular
        _loadedImage = State(initialValue: Self.initialCachedImage(for: reference, targetSize: thumbnailPixelSize))
    }

    public init(
        reference: String?,
        thumbnailPixelSize: CGSize = CGSize(width: 256, height: 256),
        layoutSize: CGSize? = nil,
        placeholderSystemImage: String = "music.note",
        cornerRadius: CGFloat = 8,
        isCircular: Bool = false
    ) {
        let ref = MediaImageReference(string: reference)
        self.mediaReference = ref
        self.thumbnailPixelSize = thumbnailPixelSize
        self.layoutSize = layoutSize
        self.placeholderSystemImage = placeholderSystemImage
        self.cornerRadius = cornerRadius
        self.isCircular = isCircular
        _loadedImage = State(initialValue: Self.initialCachedImage(for: ref, targetSize: thumbnailPixelSize))
    }

    public init(
        url: URL?,
        thumbnailPixelSize: CGSize = CGSize(width: 256, height: 256),
        layoutSize: CGSize? = nil,
        placeholderSystemImage: String = "music.note",
        cornerRadius: CGFloat = 8,
        isCircular: Bool = false
    ) {
        let ref = url.map { MediaImageReference(url: $0) }
        self.mediaReference = ref
        self.thumbnailPixelSize = thumbnailPixelSize
        self.layoutSize = layoutSize
        self.placeholderSystemImage = placeholderSystemImage
        self.cornerRadius = cornerRadius
        self.isCircular = isCircular
        _loadedImage = State(initialValue: Self.initialCachedImage(for: ref, targetSize: thumbnailPixelSize))
    }

    /// Convenience init for fixed-size thumbnail displays (e.g. Table rows).
    public init(
        reference: MediaImageReference?,
        fixedSize: CGSize,
        thumbnailPixelSize: CGSize? = nil,
        placeholderSystemImage: String = "music.note",
        cornerRadius: CGFloat = 6,
        isCircular: Bool = false
    ) {
        let pixelSize = thumbnailPixelSize ?? CGSize(width: fixedSize.width * 2, height: fixedSize.height * 2)
        self.mediaReference = reference
        self.thumbnailPixelSize = pixelSize
        self.layoutSize = fixedSize
        self.placeholderSystemImage = placeholderSystemImage
        self.cornerRadius = cornerRadius
        self.isCircular = isCircular
        _loadedImage = State(initialValue: Self.initialCachedImage(for: reference, targetSize: pixelSize))
    }

    public init(
        reference: String?,
        fixedSize: CGSize,
        thumbnailPixelSize: CGSize? = nil,
        placeholderSystemImage: String = "music.note",
        cornerRadius: CGFloat = 6,
        isCircular: Bool = false
    ) {
        let ref = MediaImageReference(string: reference)
        let pixelSize = thumbnailPixelSize ?? CGSize(width: fixedSize.width * 2, height: fixedSize.height * 2)
        self.mediaReference = ref
        self.thumbnailPixelSize = pixelSize
        self.layoutSize = fixedSize
        self.placeholderSystemImage = placeholderSystemImage
        self.cornerRadius = cornerRadius
        self.isCircular = isCircular
        _loadedImage = State(initialValue: Self.initialCachedImage(for: ref, targetSize: pixelSize))
    }

    public init(
        url: URL?,
        fixedSize: CGSize,
        thumbnailPixelSize: CGSize? = nil,
        placeholderSystemImage: String = "music.note",
        cornerRadius: CGFloat = 6,
        isCircular: Bool = false
    ) {
        let ref = url.map { MediaImageReference(url: $0) }
        let pixelSize = thumbnailPixelSize ?? CGSize(width: fixedSize.width * 2, height: fixedSize.height * 2)
        self.mediaReference = ref
        self.thumbnailPixelSize = pixelSize
        self.layoutSize = fixedSize
        self.placeholderSystemImage = placeholderSystemImage
        self.cornerRadius = cornerRadius
        self.isCircular = isCircular
        _loadedImage = State(initialValue: Self.initialCachedImage(for: ref, targetSize: pixelSize))
    }

    // MARK: - View Body

    @ViewBuilder
    public var body: some View {
        let base = baseThumbnailView

        if let ref = mediaReference, loadedImage == nil {
            base.task(id: ref) {
                let image = await MediaImagePipeline.shared.loadThumbnail(for: ref, targetSize: thumbnailPixelSize)
                if !Task.isCancelled {
                    loadedImage = image
                }
            }
        } else {
            base
        }
    }

    private var baseThumbnailView: some View {
        Group {
            if isCircular {
                Circle()
                    .fill(Color.secondary.opacity(0.12))
                    .overlay {
                        imageContent
                    }
                    .clipShape(Circle())
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
                    .overlay {
                        imageContent
                    }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        }
        .aspectRatio(1.0, contentMode: .fit)
        .modifier(LayoutFrameModifier(layoutSize: layoutSize))
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

#Preview("Artwork Placeholder") {
    HStack {
        ArtworkThumbnailView(reference: nil as String?, fixedSize: CGSize(width: 64, height: 64))
        ArtworkThumbnailView(reference: nil as String?, fixedSize: CGSize(width: 128, height: 128), isCircular: true)
    }
    .padding()
}

//
//  ArtworkThumbnailView.swift
//  MSRU
//
//  Created for Declarative On-Demand Thumbnail Loading in SwiftUI Lists and Grids.
//

import SwiftUI

public struct ArtworkThumbnailView: View {

    public let reference: String?
    public let targetSize: CGSize
    public let placeholderSystemImage: String
    public let cornerRadius: CGFloat

    @State private var loadedImage: PlatformImage? = nil

    public init(
        reference: String?,
        targetSize: CGSize = CGSize(width: 48, height: 48),
        placeholderSystemImage: String = "music.note",
        cornerRadius: CGFloat = 6
    ) {
        self.reference = reference
        self.targetSize = targetSize
        self.placeholderSystemImage = placeholderSystemImage
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        ZStack {
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
        .frame(width: targetSize.width, height: targetSize.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: reference) {
            guard let reference, !reference.isEmpty else {
                loadedImage = nil
                return
            }
            let image = await ArtworkLoader.shared.loadThumbnail(for: reference, targetSize: targetSize)
            if !Task.isCancelled {
                loadedImage = image
            }
        }
    }

    private var placeholderView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
            Image(systemName: placeholderSystemImage)
                .font(.system(size: min(targetSize.width, targetSize.height) * 0.45))
                .foregroundStyle(.secondary.opacity(0.6))
        }
    }
}

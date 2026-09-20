//
//  ArtistAvatarView.swift
//  AppFoundationUI
//

import SwiftUI
import AppFoundation

public struct ArtistAvatarView: View {
    public let artist: ArtistPresentationModel
    public let onSelect: () -> Void

    @State private var isHovered: Bool = false

    public init(
        artist: ArtistPresentationModel,
        onSelect: @escaping () -> Void
    ) {
        self.artist = artist
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(spacing: 10) {
            Circle()
                .fill(Color.secondary.opacity(0.15))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    Image(systemName: "music.mic")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
                .shadow(color: .black.opacity(isHovered ? 0.15 : 0.05), radius: isHovered ? 12 : 5, y: isHovered ? 6 : 2)
                .scaleEffect(isHovered ? 1.03 : 1.0)

            VStack(spacing: 2) {
                Text(artist.name)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                Text(artist.displaySubtitle)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Preview

#Preview("Artist Avatar View") {
    ArtistAvatarView(
        artist: ArtistPresentationModel(
            id: "preview-artist",
            name: "周杰伦",
            aliases: ["Jay Chou", "周董"],
            country: "TW",
            albumCount: 15,
            trackCount: 180
        ),
        onSelect: {}
    )
    .frame(width: 160)
    .padding()
}

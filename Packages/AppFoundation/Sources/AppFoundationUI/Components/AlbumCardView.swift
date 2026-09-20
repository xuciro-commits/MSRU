//
//  AlbumCardView.swift
//  AppFoundationUI
//

import SwiftUI
import AppFoundation

public struct AlbumCardView: View {
    public let album: AlbumPresentationModel
    public let onSelect: () -> Void
    public let onPlay: () -> Void

    @State private var isHovered: Bool = false

    public init(
        album: AlbumPresentationModel,
        onSelect: @escaping () -> Void,
        onPlay: @escaping () -> Void = {}
    ) {
        self.album = album
        self.onSelect = onSelect
        self.onPlay = onPlay
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                coverImageView
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: .black.opacity(isHovered ? 0.15 : 0.06), radius: isHovered ? 10 : 5, y: isHovered ? 6 : 2)

                if let badge = album.audioQualityBadge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(8)
                }

                if isHovered {
                    Button(action: onPlay) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 38))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white, Color.accentColor)
                            .shadow(radius: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(album.title)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                Text(album.artist)
                    .font(.subheadline)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)

                if let year = album.year {
                    Text(String(year))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
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

    @ViewBuilder
    private var coverImageView: some View {
        if let data = album.artworkData, let image = Image(foundationArtworkData: data) {
            image
                .resizable()
                .scaledToFill()
        } else if let url = album.artworkURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    placeholderNoteView
                @unknown default:
                    placeholderNoteView
                }
            }
        } else {
            placeholderNoteView
        }
    }

    private var placeholderNoteView: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.secondary.opacity(0.15))
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary.opacity(0.5))
            }
    }
}

// MARK: - Preview

#Preview("Album Card View") {
    AlbumCardView(
        album: AlbumPresentationModel(
            id: "preview-1",
            title: "叶惠美",
            artist: "周杰伦",
            year: 2003,
            artworkURL: nil,
            trackCount: 11,
            duration: 2740,
            audioQualityBadge: "Hi-Res 24/96",
            discs: []
        ),
        onSelect: {},
        onPlay: {}
    )
    .frame(width: 180)
    .padding()
}

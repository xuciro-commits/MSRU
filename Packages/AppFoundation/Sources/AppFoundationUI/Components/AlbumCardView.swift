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
        FoundationCard(
            titleText: album.title,
            subtitleText: album.artist,
            footerText: album.year != nil ? String(album.year!) : nil,
            onSelect: onSelect
        ) {
            coverImageView
        } topTrailingBadges: {
            if let badge = album.audioQualityBadge {
                FoundationCardBadge(badge)
            }
        } actionOverlay: {
            FoundationCardActionButton(systemImage: "play.fill", action: onPlay)
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

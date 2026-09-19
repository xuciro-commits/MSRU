import Foundation

extension PlaybackItem {
    /// Saved records retain provider identities. Unsupported future sources are
    /// skipped rather than mislabeled as an existing provider.
    init?(library track: LibraryTrack) {
        for source in track.sources {
            switch source.kind {
            case .local:
                guard let url = source.localFileURL, url.isFileURL else { continue }
                self.init(local: LocalTrack(fileURL: url, title: track.title, artist: track.artist,
                    album: track.album, duration: track.duration ?? 0, artworkData: track.artworkData))
                return
            case .openverse:
                guard let url = source.remoteURL,
                      ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { continue }
                self.init(openverse: OpenverseAudio(
                    id: source.externalID ?? url.absoluteString, title: track.title, creator: track.artist,
                    mediaURLString: url.absoluteString, thumbnailURLString: track.artworkURL?.absoluteString,
                    durationMilliseconds: track.duration.flatMap { Int(exactly: ($0 * 1_000).rounded()) },
                    source: "openverse"))
                return
            case .jamendo, .appleMusic, .openSubsonic:
                continue
            }
        }
        return nil
    }
}

//
//  PlaybackArtworkReference.swift
//  MSRU
//
//  Maps playback items to the app's image-pipeline references.
//

import Foundation
import MusicPlayback
import MusicLibrary

extension PlaybackItem {
    public var artworkImageReference: MediaImageReference? {
        switch payload {
        case .local(let track):
            return track.artworkReference.map { MediaImageReference(relativePath: $0) }
        case .openverse(let track):
            return track.thumbnailURL.map { MediaImageReference(url: $0) }
        case .radio(let station):
            return station.artworkURL.map { MediaImageReference(url: $0) }
        case .subsonic(_, _, _, _, _, let artworkReference, _):
            return artworkReference.flatMap { MediaImageReference(string: $0) }
        }
    }
}

extension PlaybackController {
    public var unifiedArtworkReference: MediaImageReference? {
        displayItem?.artworkImageReference
    }
}

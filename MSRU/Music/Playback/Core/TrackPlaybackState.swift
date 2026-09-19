//
//  TrackPlaybackState.swift
//  MSRU
//

import Foundation


nonisolated enum TrackPlaybackState:
    Equatable,
    Sendable {

    case idle
    case resolving
    case playing
    case paused
    case failed(String)


    var isResolving: Bool {

        if case .resolving = self {
            return true
        }

        return false
    }


    var isPlaying: Bool {

        if case .playing = self {
            return true
        }

        return false
    }


    var isFailed: Bool {

        if case .failed = self {
            return true
        }

        return false
    }
}

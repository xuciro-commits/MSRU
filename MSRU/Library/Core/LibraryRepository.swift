//
//  LibraryRepository.swift
//  MSRU
//

import Foundation


protocol LibraryRepository:
    Sendable {

    func loadTracks()
        async throws
        -> [LibraryTrack]


    func saveTracks(
        _ tracks:
            [LibraryTrack]
    ) async throws
}

//
//  AppleMusicService.swift
//  MSRU
//

import Foundation
import MusicKit


@MainActor
protocol AppleMusicLibraryServing {
    func requestAuthorization() async -> MusicAuthorization.Status
    func fetchAlbums() async throws -> [Album]
    func fetchArtists() async throws -> [Artist]
    func fetchSongs() async throws -> [Song]
}

struct AppleMusicService: AppleMusicLibraryServing {

    // MARK: - Authorization

    func requestAuthorization()
        async -> MusicAuthorization.Status {

        await MusicAuthorization.request()
    }


    // MARK: - Albums

    func fetchAlbums()
        async throws -> [Album] {

        try await fetchAll(
            Album.self
        )
    }


    // MARK: - Artists

    func fetchArtists()
        async throws -> [Artist] {

        try await fetchAll(
            Artist.self
        )
    }


    // MARK: - Songs

    func fetchSongs()
        async throws -> [Song] {

        try await fetchAll(
            Song.self
        )
    }


    // MARK: - Generic Library Request

    private func fetchAll<Item>(
        _ type: Item.Type
    ) async throws -> [Item]
    where Item: MusicLibraryRequestable {

        let pageSize = 100

        var offset = 0
        var result: [Item] = []


        while true {

            var request =
                MusicLibraryRequest<Item>()

            request.limit =
                pageSize

            request.offset =
                offset


            let response =
                try await request.response()


            let page =
                Array(response.items)


            result.append(
                contentsOf: page
            )


            guard
                page.count == pageSize
            else {
                break
            }


            offset += page.count
        }


        return result
    }
}

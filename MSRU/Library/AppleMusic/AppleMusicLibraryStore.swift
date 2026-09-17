//
//  AppleMusicLibraryStore.swift
//  MSRU
//

import Foundation
import MusicKit
import Observation


@MainActor
@Observable
final class AppleMusicLibraryStore {

    // MARK: - Content

    private(set) var albums:
        [Album] = []

    private(set) var artists:
        [Artist] = []

    private(set) var songs:
        [Song] = []


    // MARK: - State

    private(set) var authorizationStatus =
        MusicAuthorization.currentStatus

    private(set) var isImporting =
        false

    private(set) var lastError:
        String?


    // MARK: - Service

    private let service =
        AppleMusicService()


    // MARK: - Summary

    var hasContent: Bool {
        !albums.isEmpty
        || !artists.isEmpty
        || !songs.isEmpty
    }


    var albumCount: Int {
        albums.count
    }

    var artistCount: Int {
        artists.count
    }

    var songCount: Int {
        songs.count
    }


    // MARK: - Import

    @discardableResult
    func importLibrary(
        options: LibraryImportOptions
    ) async -> Bool {

        guard
            options.hasSelection
        else {
            return false
        }


        isImporting = true
        lastError = nil


        defer {
            isImporting = false
        }


        let status =
            await service
                .requestAuthorization()


        authorizationStatus =
            status


        guard
            status == .authorized
        else {
            lastError =
                "Apple Music access was not authorized."

            return false
        }


        do {

            /*
             第一版故意顺序请求。

             等流程完全稳定以后，
             再改成 TaskGroup 并发导入。
             */

            if options.importsAlbums {

                albums =
                    try await service
                        .fetchAlbums()
            }


            if options.importsArtists {

                artists =
                    try await service
                        .fetchArtists()
            }


            if options.importsSongs {

                songs =
                    try await service
                        .fetchSongs()
            }


            return true

        } catch {

            lastError =
                error.localizedDescription

            return false
        }
    }
}

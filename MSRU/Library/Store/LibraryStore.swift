//
//  LibraryStore.swift
//  MSRU
//

import Foundation
import Observation


@MainActor
@Observable
final class LibraryStore {

    // MARK: - State

    private(set) var tracks:
        [LibraryTrack] = []


    private(set) var isLoading =
        false


    private(set) var isSaving =
        false


    private(set) var hasLoaded =
        false


    private(set) var errorMessage:
        String?


    // MARK: - Repository

    private let repository:
        any LibraryRepository


    init(
        repository:
            any LibraryRepository =
                JSONLibraryRepository()
    ) {

        self.repository =
            repository
    }


    // MARK: - Load

    func load() async {

        guard !isLoading
        else {
            return
        }


        isLoading =
            true


        errorMessage =
            nil


        defer {

            isLoading =
                false
        }


        do {

            tracks =
                try await repository
                    .loadTracks()
                    .sorted {
                        lhs,
                        rhs in

                        lhs.dateAdded
                            > rhs.dateAdded
                    }


            hasLoaded =
                true

        } catch {

            errorMessage =
                error
                    .localizedDescription
        }
    }


    // MARK: - Library Identity

    /*
     LibraryTrack 自己有 UUID。

     这个 UUID 是 Library 内部 identity。

     不允许使用：

     title + artist

     自动判断两首歌是不是同一首。
     */

    func contains(
        id:
            UUID
    ) -> Bool {

        tracks.contains {
            track in

            track.id
                == id
        }
    }


    func track(
        id:
            UUID
    ) -> LibraryTrack? {

        tracks.first {
            track in

            track.id
                == id
        }
    }


    // MARK: - Source Identity

    /*
     这里允许识别：

     同一个 Provider
     +
     同一个 Provider Track ID

     这是“同一来源中的同一条记录”。

     它和：

     标题相同
     艺术家相同

     完全不是一回事。
     */

    func contains(
        source:
            LibraryPlaybackSource
    ) -> Bool {

        track(
            containing:
                source
        ) != nil
    }


    func track(
        containing source:
            LibraryPlaybackSource
    ) -> LibraryTrack? {

        tracks.first {
            track in

            track.sources
                .contains {
                    existingSource in

                    isSameSource(
                        existingSource,
                        source
                    )
                }
        }
    }


    // MARK: - Local Query

    func contains(
        local track:
            LocalTrack
    ) -> Bool {

        contains(
            source:
                LibraryPlaybackSource(
                    local:
                        track
                )
        )
    }


    func libraryTrack(
        for localTrack:
            LocalTrack
    ) -> LibraryTrack? {

        track(
            containing:
                LibraryPlaybackSource(
                    local:
                        localTrack
                )
        )
    }


    // MARK: - Openverse Query

    func contains(
        openverse track:
            OpenverseAudio
    ) -> Bool {

        contains(
            source:
                LibraryPlaybackSource(
                    openverse:
                        track
                )
        )
    }


    func libraryTrack(
        for openverseTrack:
            OpenverseAudio
    ) -> LibraryTrack? {

        track(
            containing:
                LibraryPlaybackSource(
                    openverse:
                        openverseTrack
                )
        )
    }


    // MARK: - Add Library Track

    @discardableResult
    func add(
        _ track:
            LibraryTrack
    ) async -> Bool {

        /*
         同一个 Library UUID
         不重复插入。
         */
        guard
            !contains(
                id:
                    track.id
            )
        else {

            return false
        }


        /*
         如果传入 Track 的某个 Playback Source
         已经存在于 Library：

         也不再次插入完全相同的来源。

         但绝对不根据标题/艺术家判断。
         */
        let alreadyExists =
            track.sources
                .contains {
                    source in

                    contains(
                        source:
                            source
                    )
                }


        guard !alreadyExists
        else {

            return false
        }


        tracks.insert(
            track,
            at:
                0
        )


        await persist()


        return true
    }


    // MARK: - Add Local

    @discardableResult
    func add(
        local track:
            LocalTrack
    ) async -> Bool {

        guard
            !contains(
                local:
                    track
            )
        else {

            return false
        }


        return await add(
            LibraryTrack(
                local:
                    track
            )
        )
    }


    // MARK: - Add Openverse

    @discardableResult
    func add(
        openverse track:
            OpenverseAudio
    ) async -> Bool {

        guard
            !contains(
                openverse:
                    track
            )
        else {

            return false
        }


        return await add(
            LibraryTrack(
                openverse:
                    track
            )
        )
    }


    // MARK: - Remove

    func remove(
        id:
            UUID
    ) async {

        tracks.removeAll {
            track in

            track.id
                == id
        }


        await persist()
    }


    func remove(
        local track:
            LocalTrack
    ) async {

        let source =
            LibraryPlaybackSource(
                local:
                    track
            )


        await removeTrack(
            containing:
                source
        )
    }


    func remove(
        openverse track:
            OpenverseAudio
    ) async {

        let source =
            LibraryPlaybackSource(
                openverse:
                    track
            )


        await removeTrack(
            containing:
                source
        )
    }


    private func removeTrack(
        containing source:
            LibraryPlaybackSource
    ) async {

        guard
            let libraryTrack =
                track(
                    containing:
                        source
                )
        else {

            return
        }


        await remove(
            id:
                libraryTrack.id
        )
    }


    // MARK: - Update

    func update(
        _ track:
            LibraryTrack
    ) async {

        guard
            let index =
                tracks.firstIndex(
                    where: {
                        existingTrack in

                        existingTrack.id
                            == track.id
                    }
                )
        else {

            return
        }


        tracks[
            index
        ] =
            track


        await persist()
    }


    // MARK: - Add Playback Source

    @discardableResult
    func addSource(
        _ source:
            LibraryPlaybackSource,
        toTrackID trackID:
            UUID
    ) async -> Bool {

        guard
            let index =
                tracks.firstIndex(
                    where: {
                        track in

                        track.id
                            == trackID
                    }
                )
        else {

            return false
        }


        let alreadyExists =
            tracks[
                index
            ]
            .sources
            .contains {
                existingSource in

                isSameSource(
                    existingSource,
                    source
                )
            }


        guard !alreadyExists
        else {

            return false
        }


        tracks[
            index
        ]
        .sources
        .append(
            source
        )


        await persist()


        return true
    }


    // MARK: - Played

    func markPlayed(
        id:
            UUID
    ) async {

        guard
            let index =
                tracks.firstIndex(
                    where: {
                        track in

                        track.id
                            == id
                    }
                )
        else {

            return
        }


        tracks[
            index
        ]
        .lastPlayedAt =
            Date()


        await persist()
    }


    // MARK: - Source Comparison

    private func isSameSource(
        _ lhs:
            LibraryPlaybackSource,
        _ rhs:
            LibraryPlaybackSource
    ) -> Bool {

        guard
            lhs.kind
                == rhs.kind
        else {

            return false
        }


        /*
         Provider 有稳定 external ID 时，
         这是最可信的 identity。
         */
        if let lhsID =
                lhs.externalID,
           let rhsID =
                rhs.externalID {

            return lhsID
                == rhsID
        }


        /*
         Local 文件没有稳定外部 ID 时，
         fallback 到标准化后的 URL。
         */
        if let lhsURL =
                lhs.localFileURL,
           let rhsURL =
                rhs.localFileURL {

            return lhsURL
                .standardizedFileURL
                == rhsURL
                    .standardizedFileURL
        }


        /*
         Remote Provider 最后的 fallback。
         */
        if let lhsURL =
                lhs.remoteURL,
           let rhsURL =
                rhs.remoteURL {

            return lhsURL
                == rhsURL
        }


        return false
    }


    // MARK: - Persistence

    private func persist() async {

        isSaving =
            true


        errorMessage =
            nil


        defer {

            isSaving =
                false
        }


        do {

            try await repository
                .saveTracks(
                    tracks
                )

        } catch {

            errorMessage =
                error
                    .localizedDescription
        }
    }
}

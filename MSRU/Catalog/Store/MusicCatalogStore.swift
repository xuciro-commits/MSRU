//
//  MusicCatalogStore.swift
//  MSRU
//

import Foundation
import Observation


@MainActor
@Observable
final class MusicCatalogStore {

    // MARK: - Provider

    private(set) var selectedProvider:
        MusicProviderID = .musicBrainz


    // MARK: - Content

    private(set) var sections:
        [MusicSection] = []

    private(set) var searchResults:
        [MusicContent] = []


    // MARK: - State

    private(set) var isLoading =
        false

    private(set) var errorMessage:
        String?

    private var didAttemptHomeLoad =
        false


    // MARK: - Infrastructure

    private let musicBrainz =
        MusicBrainzCatalogProvider()

    private let cache =
        MusicCatalogCache()


    // MARK: - Provider Selection

    func selectProvider(
        _ providerID:
            MusicProviderID
    ) async {

        guard
            providerID
                .isAvailable
        else {
            return
        }


        guard
            selectedProvider
                != providerID
        else {
            return
        }


        selectedProvider =
            providerID

        sections = []

        searchResults = []

        errorMessage = nil

        didAttemptHomeLoad =
            false


        await loadHomeIfNeeded()
    }


    // MARK: - Automatic Home Loading

    func loadHomeIfNeeded()
        async {

        guard
            !didAttemptHomeLoad
        else {

            print(
                "Catalog Home → memory cache"
            )

            return
        }


        didAttemptHomeLoad =
            true


        /*
         先读磁盘。

         这一部分完全不访问网络。
         */

        if let snapshot =
            await cache.load(
                provider:
                    selectedProvider
            ) {

            sections =
                snapshot.sections


            print(
                "Catalog Cache ✓",
                snapshot.sections.count,
                "sections"
            )


            /*
             24 小时以内的数据直接使用。

             不请求 MusicBrainz。
             */

            if snapshot.isFresh {

                print(
                    "Catalog Cache → fresh, skip network"
                )

                return
            }


            /*
             缓存虽然旧了，
             但是先保留在 UI 上。

             网络刷新失败也不会白屏。
             */

            print(
                "Catalog Cache → stale, refreshing"
            )
        }


        await refreshHome()
    }


    // MARK: - Manual Reload

    func reloadHome()
        async {

        didAttemptHomeLoad =
            true

        await refreshHome()
    }


    // MARK: - Network Refresh

    private func refreshHome()
        async {

        guard
            !isLoading
        else {

            print(
                "Catalog Home → request already running"
            )

            return
        }


        isLoading =
            true

        errorMessage =
            nil


        defer {
            isLoading = false
        }


        do {

            let newSections =
                try await currentProvider
                    .homeSections()


            guard
                !newSections.isEmpty
            else {
                return
            }


            /*
             网络成功以后，
             一次性替换内存内容。
             */

            sections =
                newSections


            /*
             然后持久化。

             下次 App 重启无需请求网络。
             */

            await cache.save(
                sections:
                    newSections,
                provider:
                    selectedProvider
            )


            print(
                "Catalog Home ✓",
                sections.count,
                "sections"
            )

        } catch {

            errorMessage =
                error.localizedDescription


            /*
             注意：
             这里绝对不清空 sections。

             如果已经存在旧缓存，
             UI 继续正常显示。
             */

            print(
                "Catalog Home failed:",
                error.localizedDescription
            )
        }
    }


    // MARK: - Search

    func search(
        _ query:
            String
    ) async {

        let trimmed =
            query.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )


        guard
            !trimmed.isEmpty
        else {

            searchResults = []

            return
        }


        guard
            !isLoading
        else {
            return
        }


        isLoading =
            true

        errorMessage =
            nil


        defer {
            isLoading = false
        }


        do {

            searchResults =
                try await currentProvider
                    .search(
                        trimmed
                    )

        } catch {

            searchResults = []

            errorMessage =
                error.localizedDescription
        }
    }


    // MARK: - Provider

    private var currentProvider:
        any MusicCatalogProvider {

        switch selectedProvider {

        case .musicBrainz:

            musicBrainz


        case .appleMusic:

            fatalError(
                "Apple Music provider is not available."
            )


        case .jamendo:

            fatalError(
                "Jamendo provider is not available."
            )
        }
    }
}

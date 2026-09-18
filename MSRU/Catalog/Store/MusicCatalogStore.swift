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
        MusicProviderID


    private let providers:
        [MusicProviderID: any MusicCatalogProvider]


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

    private let cache:
        any MusicCatalogCaching


    // MARK: - Init

    init(
        selectedProvider:
            MusicProviderID = .musicBrainz,
        providers:
            [MusicProviderID: any MusicCatalogProvider]? = nil,
        cache:
            any MusicCatalogCaching = MusicCatalogCache()
    ) {

        let resolvedProviders =
            providers
            ?? [
                .musicBrainz:
                    MusicBrainzCatalogProvider()
            ]


        precondition(
            resolvedProviders[
                selectedProvider
            ] != nil,
            """
            MusicCatalogStore requires a registered provider \
            for \(selectedProvider.rawValue).
            """
        )


        self.selectedProvider =
            selectedProvider

        self.providers =
            resolvedProviders

        self.cache =
            cache
    }


    // MARK: - Availability

    var availableProviderIDs:
        [MusicProviderID] {

        MusicProviderID
            .allCases
            .filter {
                providers[$0] != nil
            }
    }


    func isProviderAvailable(
        _ providerID:
            MusicProviderID
    ) -> Bool {

        providers[
            providerID
        ] != nil
    }


    // MARK: - Provider Selection

    func selectProvider(
        _ providerID:
            MusicProviderID
    ) async {

        guard
            isProviderAvailable(
                providerID
            )
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
         优先读取 Cache。

         Live 环境：
         → Application Support

         Preview / Test：
         → 可以替换成纯内存 Cache。
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
             新鲜 Cache 直接使用。

             Preview Cache 默认也是 fresh，
             所以 Preview 不会继续访问网络。
             */

            if snapshot.isFresh {

                print(
                    "Catalog Cache → fresh, skip provider refresh"
                )

                return
            }


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


    // MARK: - Provider Refresh

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


        guard
            let provider =
                currentProvider
        else {

            errorMessage =
                "Catalog provider \(selectedProvider.title) is unavailable."

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
                try await provider
                    .homeSections()


            guard
                !newSections.isEmpty
            else {
                return
            }


            sections =
                newSections


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
             如果已有 Cache，
             不清空原来的 sections。
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


        guard
            let provider =
                currentProvider
        else {

            searchResults = []

            errorMessage =
                "Catalog provider \(selectedProvider.title) is unavailable."

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
                try await provider
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
        (any MusicCatalogProvider)? {

        providers[
            selectedProvider
        ]
    }
}

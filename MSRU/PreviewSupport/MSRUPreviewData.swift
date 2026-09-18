//
//  MSRUPreviewData.swift
//  MSRU
//

import Foundation


// MARK: - Preview Data

enum MSRUPreviewData {

    // MARK: Music Content

    static let featuredAlbum =
        MusicContent(
            id:
                "preview-featured",
            provider:
                .musicBrainz,
            kind:
                .album,
            title:
                "Northern Lights",
            subtitle:
                "Aurora Ensemble"
        )


    static let albumOne =
        MusicContent(
            id:
                "preview-album-1",
            provider:
                .musicBrainz,
            kind:
                .album,
            title:
                "Quiet Geometry",
            subtitle:
                "Mira Vale"
        )


    static let albumTwo =
        MusicContent(
            id:
                "preview-album-2",
            provider:
                .musicBrainz,
            kind:
                .album,
            title:
                "Glass Gardens",
            subtitle:
                "Lumen"
        )


    static let albumThree =
        MusicContent(
            id:
                "preview-album-3",
            provider:
                .musicBrainz,
            kind:
                .album,
            title:
                "Signals After Rain",
            subtitle:
                "Northbound"
        )


    static let albumFour =
        MusicContent(
            id:
                "preview-album-4",
            provider:
                .musicBrainz,
            kind:
                .album,
            title:
                "Slow Orbit",
            subtitle:
                "Paper Moon"
        )


    static let albumFive =
        MusicContent(
            id:
                "preview-album-5",
            provider:
                .musicBrainz,
            kind:
                .album,
            title:
                "A Very Long Album Title Used to Verify Truncation and Layout",
            subtitle:
                "Preview Artist"
        )


    static let albumWithoutSubtitle =
        MusicContent(
            id:
                "preview-no-subtitle",
            provider:
                .musicBrainz,
            kind:
                .album,
            title:
                "Untitled Studies"
        )


    static let albums:
        [MusicContent] = [

            featuredAlbum,
            albumOne,
            albumTwo,
            albumThree,
            albumFour,
            albumFive,
            albumWithoutSubtitle
        ]


    // MARK: Sections

    static let featuredSection =
        MusicSection(
            id:
                "preview-featured-section",
            title:
                "Featured",
            subtitle:
                "Selected for the preview environment",
            layout:
                .featured,
            items: [
                featuredAlbum,
                albumOne,
                albumTwo
            ]
        )


    static let shelfSection =
        MusicSection(
            id:
                "preview-shelf-section",
            title:
                "Recently Added",
            subtitle:
                "Standard card presentation",
            layout:
                .shelf,
            items:
                albums
        )


    static let compactSection =
        MusicSection(
            id:
                "preview-compact-section",
            title:
                "Made for You",
            subtitle:
                "Compact card presentation",
            layout:
                .compactShelf,
            items:
                albums
        )


    static let gridSection =
        MusicSection(
            id:
                "preview-grid-section",
            title:
                "Albums",
            subtitle:
                "Adaptive grid presentation",
            layout:
                .grid,
            items:
                albums
        )


    static let listenNowSections:
        [MusicSection] = [

            featuredSection,
            shelfSection,
            compactSection,
            gridSection
        ]


    // MARK: Store

    @MainActor
    static func makeCatalogStore()
        -> MusicCatalogStore {

        let provider =
            PreviewMusicCatalogProvider(
                id:
                    .musicBrainz,
                homeSections:
                    listenNowSections,
                searchResults:
                    albums
            )


        let cache =
            PreviewMusicCatalogCache(
                sectionsByProvider: [
                    .musicBrainz:
                        listenNowSections
                ]
            )


        return MusicCatalogStore(
            selectedProvider:
                .musicBrainz,
            providers: [
                .musicBrainz:
                    provider
            ],
            cache:
                cache
        )
    }
}


// MARK: - Preview Catalog Provider

private struct PreviewMusicCatalogProvider:
    MusicCatalogProvider {

    let id:
        MusicProviderID

    let homeSectionsValue:
        [MusicSection]

    let searchResults:
        [MusicContent]


    init(
        id:
            MusicProviderID,
        homeSections:
            [MusicSection],
        searchResults:
            [MusicContent]
    ) {

        self.id =
            id

        self.homeSectionsValue =
            homeSections

        self.searchResults =
            searchResults
    }


    func homeSections()
        async throws -> [MusicSection] {

        homeSectionsValue
    }


    func search(
        _ query:
            String
    ) async throws -> [MusicContent] {

        let normalized =
            query
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .lowercased()


        guard
            !normalized.isEmpty
        else {
            return []
        }


        return searchResults
            .filter {

                $0.title
                    .lowercased()
                    .contains(
                        normalized
                    )
                ||
                ($0.subtitle ?? "")
                    .lowercased()
                    .contains(
                        normalized
                    )
            }
    }
}


// MARK: - Preview Cache

private actor PreviewMusicCatalogCache:
    MusicCatalogCaching {

    private var sectionsByProvider:
        [MusicProviderID: [MusicSection]]


    init(
        sectionsByProvider:
            [MusicProviderID: [MusicSection]] = [:]
    ) {

        self.sectionsByProvider =
            sectionsByProvider
    }


    func load(
        provider:
            MusicProviderID
    ) async -> MusicCatalogCacheSnapshot? {

        guard
            let sections =
                sectionsByProvider[
                    provider
                ]
        else {
            return nil
        }


        return MusicCatalogCacheSnapshot(
            sections:
                sections,
            fetchedAt:
                Date(),
            isFresh:
                true
        )
    }


    func save(
        sections:
            [MusicSection],
        provider:
            MusicProviderID
    ) async {

        sectionsByProvider[
            provider
        ] = sections
    }


    func clear(
        provider:
            MusicProviderID
    ) async {

        sectionsByProvider[
            provider
        ] = nil
    }
}

// MARK: - Browse Preview

extension MSRUPreviewData {

    static let openverseOne =
        OpenverseAudio(
            id:
                "preview-openverse-1",
            title:
                "Morning Field Recording",
            creator:
                "Preview Artist",
            mediaURLString:
                "file:///tmp/msru-preview-audio-1.mp3",
            durationMilliseconds:
                184_000,
            filetype:
                "mp3",
            provider:
                "wikimedia",
            source:
                "openverse",
            license:
                "cc0",
            licenseVersion:
                "1.0",
            descriptionText:
                "A quiet field recording used by the local preview environment."
        )


    static let openverseTwo =
        OpenverseAudio(
            id:
                "preview-openverse-2",
            title:
                "Piano Study No. 4",
            creator:
                "Mira Vale",
            mediaURLString:
                "file:///tmp/msru-preview-audio-2.mp3",
            durationMilliseconds:
                256_000,
            filetype:
                "mp3",
            provider:
                "jamendo",
            source:
                "openverse",
            license:
                "by",
            licenseVersion:
                "4.0",
            descriptionText:
                "Openly licensed piano recording."
        )


    static let openverseThree =
        OpenverseAudio(
            id:
                "preview-openverse-3",
            title:
                "Signals After Rain",
            creator:
                "Northbound",
            mediaURLString:
                "file:///tmp/msru-preview-audio-3.mp3",
            durationMilliseconds:
                221_000,
            filetype:
                "m4a",
            provider:
                "freesound",
            source:
                "openverse",
            license:
                "by-sa",
            licenseVersion:
                "4.0",
            descriptionText:
                "Ambient recording with a deliberately longer description for layout testing."
        )


    static let openverseFour =
        OpenverseAudio(
            id:
                "preview-openverse-4",
            title:
                "A Very Long Recording Title Used to Test the Browse Card Layout",
            creator:
                nil,
            mediaURLString:
                "file:///tmp/msru-preview-audio-4.mp3",
            durationMilliseconds:
                95_000,
            filetype:
                "wav",
            provider:
                "internet_archive",
            source:
                "openverse",
            license:
                "cc0"
        )


    static let openverseResults:
        [OpenverseAudio] = [

            openverseOne,
            openverseTwo,
            openverseThree,
            openverseFour
        ]


    @MainActor
    static func makeBrowseFeature()
        -> FeatureHost<BrowseFeature> {

        /*
         Preview dependencies 是一整个环境，
         而不是 Service initializer 参数。
         */

        let library =
            LibraryStore(
                repository:
                    PreviewLibraryRepository()
            )


        let playback =
            PlaybackController()


        let state =
            BrowseFeature.State(
                query:
                    "preview",
                results:
                    openverseResults
            )


        var dependencies =
            DependencyValues
                .preview


        dependencies.openverseSearch =
            .preview(
                results:
                    openverseResults
            )


        dependencies.playback =
            playback


        dependencies.library =
            library


        return withDependencies(
            dependencies
        ) {

            FeatureHost<BrowseFeature>(
                state:
                    state,
                service:
                    BrowseFeature
                        .Service()
            )
        }
    }
}


// MARK: - Preview Library Repository

private actor PreviewLibraryRepository:
    LibraryRepository {

    private var tracks:
        [LibraryTrack] = []


    func loadTracks()
        async throws
        -> [LibraryTrack] {

        tracks
    }


    func saveTracks(
        _ tracks:
            [LibraryTrack]
    ) async throws {

        self.tracks =
            tracks
    }
}

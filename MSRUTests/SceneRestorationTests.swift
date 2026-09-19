//
//  SceneRestorationTests.swift
//  MSRUTests
//

import Foundation
import Testing

@testable import MSRU


// MARK: - Repository

@MainActor
private final class RestorationTestLibraryRepository:
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


// MARK: - Application Factory

@MainActor
private func makeRestorationTestApplication()
    -> ApplicationModel {

    ApplicationModel(
        musicCatalog:
            MusicCatalogStore(),
        localLibrary:
            LocalLibraryStore(),
        library:
            LibraryStore(
                repository:
                    RestorationTestLibraryRepository()
            ),
        musicLibrary:
            AppleMusicLibraryStore(),
        playback:
            PlaybackController(),
        providerManager:
            ProviderManagerStore(),
        openverseSearch:
            .preview(
                results:
                    []
            )
    )
}


// MARK: - Tests

@MainActor
struct SceneRestorationTests {

    @Test
    func sceneHasStableTypedIdentity() {

        let application =
            makeRestorationTestApplication()


        let scene =
            SceneModel(
                application:
                    application
            )


        let snapshot =
            scene
                .restorationSnapshot()


        #expect(
            snapshot.sceneID
            ==
            scene.id
        )
    }


    @Test
    func snapshotCapturesSemanticSceneState() {

        let application =
            makeRestorationTestApplication()


        let scene =
            SceneModel(
                application:
                    application
            )


        scene
            .navigation
            .select(
                .library
            )


        scene.isQueuePresented =
            false


        let snapshot =
            scene
                .restorationSnapshot()


        #expect(
            snapshot.section
            ==
            .library
        )


        #expect(
            snapshot.isQueuePresented
            ==
            false
        )
    }


    @Test
    func snapshotSupportsJSONRoundTrip()
        throws {

        let original =
            SceneRestorationSnapshot(
                sceneID:
                    SceneID(),
                section:
                    .browse,
                isQueuePresented:
                    false
            )


        let data =
            try JSONEncoder()
                .encode(
                    original
                )


        let decoded =
            try JSONDecoder()
                .decode(
                    SceneRestorationSnapshot.self,
                    from:
                        data
                )


        #expect(
            decoded
            ==
            original
        )
    }


    @Test
    func restoredSceneKeepsIdentityAndNavigation()
        throws {

        let application =
            makeRestorationTestApplication()


        let original =
            SceneModel(
                application:
                    application
            )


        original
            .navigation
            .select(
                .settings
            )


        original.isQueuePresented =
            false


        let snapshot =
            original
                .restorationSnapshot()


        let restored =
            try #require(
                SceneModel(
                    application:
                        application,
                    restoration:
                        snapshot
                )
            )


        #expect(
            restored.id
            ==
            original.id
        )


        #expect(
            restored
                .navigation
                .section
            ==
            .settings
        )


        #expect(
            restored.isQueuePresented
            ==
            false
        )
    }


    @Test
    func restoredSceneGetsFreshRuntime() throws {

        let application =
            makeRestorationTestApplication()


        let original =
            SceneModel(
                application:
                    application
            )


        let snapshot =
            original
                .restorationSnapshot()


        let restored =
            try #require(
                SceneModel(
                    application:
                        application,
                    restoration:
                        snapshot
                )
            )


        /*
         Feature runtime 不允许被 Restoration
         序列化或复用。
         */

        #expect(
            original.browse
            !==
            restored.browse
        )


        #expect(
            original.libraryFeature
            !==
            restored.libraryFeature
        )


        #expect(
            original.browse.state
            !==
            restored.browse.state
        )
    }


    @Test
    func restoredSceneReconnectsApplicationScope()
        throws {

        let application =
            makeRestorationTestApplication()


        let original =
            SceneModel(
                application:
                    application
            )


        let restored =
            try #require(
                SceneModel(
                    application:
                        application,
                    restoration:
                        original
                            .restorationSnapshot()
                )
            )


        /*
         Scene Runtime 是新的。

         Application Scope 仍然必须是原来的
         shared services。
         */

        #expect(
            restored.application
            ===
            original.application
        )


        #expect(
            restored
                .application
                .library
            ===
            original
                .application
                .library
        )


        #expect(
            restored
                .application
                .playback
            ===
            original
                .application
                .playback
        )
    }


    @Test
    func unsupportedSnapshotVersionIsRejected() {

        let application =
            makeRestorationTestApplication()


        let snapshot =
            SceneRestorationSnapshot(
                version:
                    SceneRestorationSnapshot
                        .currentVersion
                    + 1,
                sceneID:
                    SceneID(),
                section:
                    .listenNow,
                isQueuePresented:
                    true
            )


        let restored =
            SceneModel(
                application:
                    application,
                restoration:
                    snapshot
            )


        #expect(
            restored
            ==
            nil
        )
    }
}

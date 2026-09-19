//
//  MSRUTests.swift
//  MSRUTests
//

import Testing
import AppFoundation

@testable import MSRU


// MARK: - Runtime Probe Dependency

@MainActor
private enum RuntimeProbeDependencyKey:
    DependencyKey {

    static let liveValue =
        0


    static let previewValue =
        1


    static let testValue =
        2
}


@MainActor
private extension DependencyValues {

    var runtimeProbe:
        Int {

        get {

            self[
                RuntimeProbeDependencyKey
                    .self
            ]
        }


        set {

            self[
                RuntimeProbeDependencyKey
                    .self
            ] =
                newValue
        }
    }
}


// MARK: - Dependency Capture Feature

private enum DependencyCaptureFeature:
    Feature {

    @MainActor
    final class State {

        var capturedValue:
            Int?


        init(
            capturedValue:
                Int? = nil
        ) {

            self.capturedValue =
                capturedValue
        }
    }


    enum Action {

        case capture
    }


    @MainActor
    struct Service:
        FeatureService {

        @Dependency(
            \.runtimeProbe
        )
        private var runtimeProbe:
            Int


        init() {}


        func handle(
            _ action:
                Action,
            state:
                State
        ) -> [FeatureTask<Action>] {

            switch action {

            case .capture:

                state.capturedValue =
                    runtimeProbe


                return []
            }
        }
    }


    @MainActor
    static func makeInitialState()
        -> State {

        State()
    }
}


// MARK: - Cancellation Feature

@MainActor
private final class CancellationSignal {
    private var fired = false
    private var continuation: CheckedContinuation<Void, Never>?
    func wait() async {
        if fired { return }
        await withCheckedContinuation { continuation = $0 }
    }
    func fire() {
        fired = true
        continuation?.resume()
        continuation = nil
    }
}

private enum CancellationFeature: Feature {
    @MainActor final class State { var completedValues: [Int] = [] }
    enum Action { case start(Int), finished(Int) }
    @MainActor struct Service: FeatureService {
        let work: @MainActor (Int) async -> Void
        let completed: @MainActor (Int) -> Void
        func handle(_ action: Action, state: State) -> [FeatureTask<Action>] {
            switch action {
            case .start(let value):
                return [.run(id: "tests.cancellation.work", cancelInFlight: true) { send in
                    await work(value)
                    // Intentionally non-cooperative: the host must reject revoked callbacks.
                    send(.finished(value))
                    completed(value)
                }]
            case .finished(let value):
                state.completedValues.append(value)
                return []
            }
        }
    }
    @MainActor static func makeInitialState() -> State { State() }
}


// MARK: - Scope Test Library Repository

@MainActor
private final class ScopeTestLibraryRepository:
    LibraryRepository {

    private var tracks:
        [LibraryTrack]


    init(
        tracks:
            [LibraryTrack] = []
    ) {

        self.tracks =
            tracks
    }


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


// MARK: - Test Application Factory

@MainActor
private func makeTestApplication(
    openverseResults:
        [OpenverseAudio] = []
) -> ApplicationModel {

    let library =
        LibraryStore(
            repository:
                ScopeTestLibraryRepository()
        )


    return ApplicationModel(
        musicCatalog:
            MusicCatalogStore(),
        localLibrary:
            LocalLibraryStore(),
        library:
            library,
        musicLibrary:
            AppleMusicLibraryStore(),
        playback:
            PlaybackController(),
        providerManager:
            ProviderManagerStore(),
        openverseSearch:
            .preview(
                results:
                    openverseResults
            )
    )
}


// MARK: - Tests

@MainActor
struct MSRUTests {

    // =========================================================
    // MARK: Dependency Environment
    // =========================================================

    @Test
    func dependencyEnvironmentDefaultsAreSeparated()
        async throws {

        #expect(
            DependencyValues
                .live
                .runtimeProbe
            == 0
        )


        #expect(
            DependencyValues
                .preview
                .runtimeProbe
            == 1
        )


        #expect(
            DependencyValues
                .test
                .runtimeProbe
            == 2
        )
    }


    // =========================================================
    // MARK: Dependency Override Isolation
    // =========================================================

    @Test
    func dependencyOverridesAreScoped() {

        #expect(
            DependencyValues
                .current
                .runtimeProbe
            == 0
        )


        var outer =
            DependencyValues
                .test


        outer.runtimeProbe =
            10


        let innerResult =
            withDependencies(
                outer
            ) {

                #expect(
                    DependencyValues
                        .current
                        .runtimeProbe
                    == 10
                )


                var inner =
                    DependencyValues
                        .current


                inner.runtimeProbe =
                    20


                return withDependencies(
                    inner
                ) {

                    DependencyValues
                        .current
                        .runtimeProbe
                }
            }


        #expect(
            innerResult
            == 20
        )


        /*
         Scope 退出以后，
         外部 DependencyValues 不允许被污染。
         */

        #expect(
            DependencyValues
                .current
                .runtimeProbe
            == 0
        )
    }


    // =========================================================
    // MARK: FeatureHost Dependency Capture
    // =========================================================

    @Test
    func featureHostCapturesDependencyScope() {

        var creationDependencies =
            DependencyValues
                .test


        creationDependencies.runtimeProbe =
            42


        let host =
            withDependencies(
                creationDependencies
            ) {

                FeatureHost<
                    DependencyCaptureFeature
                >(
                    service:
                        DependencyCaptureFeature
                            .Service()
                )
            }


        /*
         FeatureHost 创建以后，
         外面的 dependency context 即使变化，
         已创建的 Feature Runtime
         也应该继续使用原 snapshot。
         */

        var differentDependencies =
            DependencyValues
                .test


        differentDependencies.runtimeProbe =
            999


        withDependencies(
            differentDependencies
        ) {

            host.send(
                .capture
            )
        }


        #expect(
            host
                .state
                .capturedValue
            == 42
        )
    }


    // =========================================================
    // MARK: Safe Test Dependency
    // =========================================================

    @Test
    func testOpenverseDependencyDoesNotUseLiveNetwork()
        async throws {

        let results =
            try await DependencyValues
                .test
                .openverseSearch
                .search(
                    "this-must-not-hit-network"
                )


        #expect(
            results.isEmpty
        )
    }


    // =========================================================
    // MARK: Browse Runtime
    // =========================================================

    @Test
    func browseRunsInsideTestDependencyEnvironment()
        async throws {

        let host =
            withDependencies(
                DependencyValues
                    .test
            ) {

                FeatureHost<BrowseFeature>(
                    service:
                        BrowseFeature
                            .Service()
                )
            }


        host.send(
            .appeared
        )


        /*
         Test Openverse implementation
         是 deterministic 空结果。

         等异步 request 完成。
         */

        for _ in 0..<100 {

            if !host.state.isLoading {

                break
            }


            try await Task
                .sleep(
                    nanoseconds:
                        5_000_000
                )
        }


        #expect(
            host
                .state
                .isLoading
            == false
        )


        #expect(
            host
                .state
                .errorMessage
            == nil
        )


        #expect(
            host
                .state
                .results
                .isEmpty
        )
    }


    // =========================================================
    // MARK: FeatureTask Cancellation
    // =========================================================

    @Test
    func cancelInFlightReplacesPreviousTask() async {
        let started = (0..<3).map { _ in CancellationSignal() }
        let release = (0..<3).map { _ in CancellationSignal() }
        let finished = (0..<3).map { _ in CancellationSignal() }
        let host = FeatureHost<CancellationFeature>(service: .init(work: { value in
            started[value - 1].fire()
            await release[value - 1].wait()
        }, completed: { value in finished[value - 1].fire() }))

        host.send(.start(1))
        await started[0].wait()
        host.send(.start(2))
        await started[1].wait()
        release[1].fire()
        await finished[1].wait()
        release[0].fire()
        await finished[0].wait()
        #expect(host.state.completedValues == [2])

        host.send(.start(3))
        await started[2].wait()
        host.cancelAll()
        release[2].fire()
        await finished[2].wait()
        #expect(host.state.completedValues == [2])
    }


    // =========================================================
    // MARK: Application Scope
    // =========================================================

    @Test
    func scenesShareTheSameApplicationScope() {

        let application =
            makeTestApplication()


        let sceneA =
            SceneModel(
                application:
                    application
            )


        let sceneB =
            SceneModel(
                application:
                    application
            )


        /*
         两个 Scene 必须指向同一个
         ApplicationModel。
         */

        #expect(
            sceneA.application
            ===
            sceneB.application
        )


        /*
         Application-scoped services
         也必须天然共享。
         */

        #expect(
            sceneA
                .application
                .library
            ===
            sceneB
                .application
                .library
        )


        #expect(
            sceneA
                .application
                .playback
            ===
            sceneB
                .application
                .playback
        )


        #expect(
            sceneA
                .application
                .musicCatalog
            ===
            sceneB
                .application
                .musicCatalog
        )
    }


    // =========================================================
    // MARK: Scene Scope
    // =========================================================

    @Test
    func scenesOwnIndependentFeatureHosts() {

        let application =
            makeTestApplication()


        let sceneA =
            SceneModel(
                application:
                    application
            )


        let sceneB =
            SceneModel(
                application:
                    application
            )


        /*
         Feature runtime 属于 Scene Scope。

         即使两个 Scene 共用同一个 Application，
         Browse / Library FeatureHost
         也不能是同一个实例。
         */

        #expect(
            sceneA.browse
            !==
            sceneB.browse
        )


        #expect(
            sceneA.libraryFeature
            !==
            sceneB.libraryFeature
        )


        #expect(
            sceneA.browse.state
            !==
            sceneB.browse.state
        )


        #expect(
            sceneA.libraryFeature.state
            !==
            sceneB.libraryFeature.state
        )
    }


    // =========================================================
    // MARK: Scene Selection Isolation
    // =========================================================

    @Test
    func sceneSelectionDoesNotLeakBetweenWindows() {

        let application =
            makeTestApplication()


        let sceneA =
            SceneModel(
                application:
                    application
            )


        let sceneB =
            SceneModel(
                application:
                    application
            )


        #expect(
            sceneA.navigation.section
            == .listenNow
        )


        #expect(
            sceneB.navigation.section
            == .listenNow
        )


        sceneA
            .navigation
            .select(
                .browse
            )


        #expect(
            sceneA.navigation.section
            == .browse
        )


        /*
         Scene B 不应该跟着 Scene A
         一起切换页面。
         */

        #expect(
            sceneB.navigation.section
            == .listenNow
        )


        /*
         Feature State 同样独立。
         */

        sceneA.browse.send(
            .queryChanged(
                "scene-a-query"
            )
        )


        #expect(
            sceneA
                .browse
                .state
                .query
            == "scene-a-query"
        )


        #expect(
            sceneB
                .browse
                .state
                .query
            == "mozart"
        )


        /*
         queryChanged 会创建 debounce task。
         测试结束前明确清理。
         */

        sceneA
            .browse
            .cancelAll()
    }


    // =========================================================
    // MARK: Shared Application Data Through Independent Features
    // =========================================================

    @Test
    func sceneFeaturesObserveSharedApplicationLibrary()
        async throws {

        let item =
            MSRUPreviewData
                .openverseOne


        let application =
            makeTestApplication(
                openverseResults: [
                    item
                ]
            )


        let sceneA =
            SceneModel(
                application:
                    application
            )


        let sceneB =
            SceneModel(
                application:
                    application
            )


        /*
         FeatureHosts 本身彼此独立。
         */

        #expect(
            sceneA.browse
            !==
            sceneB.browse
        )


        /*
         开始时共享 Library 为空。
         */

        #expect(
            !sceneA
                .browse
                .isSaved(
                    item
                )
        )


        #expect(
            !sceneB
                .browse
                .isSaved(
                    item
                )
        )


        /*
         直接修改 Application Scope
         中唯一的 LibraryStore。
         */

        await application
            .library
            .add(
                openverse:
                    item
            )


        /*
         两个不同 Scene 的 Browse Service
         应该同时看到这个变化。

         这验证：

         Scene FeatureHost 独立，
         Application dependency shared。
         */

        #expect(
            sceneA
                .browse
                .isSaved(
                    item
                )
        )


        #expect(
            sceneB
                .browse
                .isSaved(
                    item
                )
        )
    }
}

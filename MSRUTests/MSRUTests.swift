//
//  MSRUTests.swift
//  MSRUTests
//

import Testing

@testable import MSRU


// MARK: - Test Dependency

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

private enum CancellationFeature:
    Feature {

    @MainActor
    final class State {

        var completedValues:
            [Int] = []
    }


    enum Action {

        case start(
            Int
        )

        case finished(
            Int
        )
    }


    @MainActor
    struct Service:
        FeatureService {

        private static let taskID:
            FeatureTaskID =
                "tests.cancellation.work"


        init() {}


        func handle(
            _ action:
                Action,
            state:
                State
        ) -> [FeatureTask<Action>] {

            switch action {

            case .start(
                let value
            ):

                return [

                    .run(
                        id:
                            Self.taskID,
                        cancelInFlight:
                            true
                    ) {
                        send in

                        do {

                            try await Task
                                .sleep(
                                    nanoseconds:
                                        80_000_000
                                )

                        } catch {

                            return
                        }


                        guard
                            !Task.isCancelled
                        else {

                            return
                        }


                        send(
                            .finished(
                                value
                            )
                        )
                    }
                ]


            case .finished(
                let value
            ):

                state
                    .completedValues
                    .append(
                        value
                    )


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


// MARK: - Tests

@MainActor
struct MSRUTests {

    // MARK: Dependency Environments

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


    // MARK: Override Isolation

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
         TaskLocal scope 退出以后，
         外部环境没有被污染。
         */

        #expect(
            DependencyValues
                .current
                .runtimeProbe
            == 0
        )
    }


    // MARK: FeatureHost Dependency Capture

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
         Host 创建完成后，
         外部 Dependency context 再变化，
         不应该改变这个 Feature runtime。
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


    // MARK: Safe Test Environment

    @Test
    func testOpenverseDependencyDoesNotUseLiveNetwork()
        async throws {

        /*
         testValue 是本地空实现。

         如果这里未来被错误地改回 .live，
         这个测试就失去了 deterministic 特性。
         */

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


    // MARK: Browse Test Runtime

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
         Test Openverse client 返回空结果，
         所以 Browse 应该快速结束 loading，
         而且没有网络错误。
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


    // MARK: Task Replacement

    @Test
    func cancelInFlightReplacesPreviousTask()
        async throws {

        let host =
            FeatureHost<CancellationFeature>(
                service:
                    CancellationFeature
                        .Service()
            )


        host.send(
            .start(
                1
            )
        )


        host.send(
            .start(
                2
            )
        )


        try await Task
            .sleep(
                nanoseconds:
                    180_000_000
            )


        /*
         第一项应该被第二项替换。
         */

        #expect(
            host
                .state
                .completedValues
            == [
                2
            ]
        )


        // MARK: cancelAll

        host.send(
            .start(
                3
            )
        )


        host.cancelAll()


        try await Task
            .sleep(
                nanoseconds:
                    120_000_000
            )


        /*
         cancelAll 后 3 不允许完成。
         */

        #expect(
            host
                .state
                .completedValues
            == [
                2
            ]
        )
    }
}

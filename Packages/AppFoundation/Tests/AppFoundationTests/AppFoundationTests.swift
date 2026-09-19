//
//  AppFoundationTests.swift
//  AppFoundationTests
//

import Testing

@testable import AppFoundation


// MARK: - Dependency Test Key

@MainActor
private enum StepDependencyKey:
    DependencyKey {

    static var liveValue:
        Int {

        1
    }


    static var previewValue:
        Int {

        2
    }


    static var testValue:
        Int {

        3
    }
}


// MARK: - Dependency Surface

private extension DependencyValues {

    @MainActor
    var testStep:
        Int {

        get {

            self[
                StepDependencyKey
                    .self
            ]
        }


        set {

            self[
                StepDependencyKey
                    .self
            ] =
                newValue
        }
    }
}


// MARK: - Dummy Feature

@MainActor
private enum CounterFeature:
    Feature {

    // MARK: State

    final class State {

        var value =
            0
    }


    // MARK: Action

    enum Action {

        case increment
    }


    // MARK: Service

    struct Service:
        FeatureService {

        @Dependency(
            \.testStep
        )
        private var step


        init() {}


        func handle(
            _ action:
                Action,
            state:
                State
        ) -> [FeatureTask<Action>] {

            switch action {

            case .increment:

                state.value +=
                    step


                return []
            }
        }
    }


    // MARK: Initial State

    static func makeInitialState()
        -> State {

        State()
    }
}


// MARK: - Tests

@MainActor
struct AppFoundationTests {

    @Test
    func dependencyEnvironmentsAreExplicit() {

        #expect(
            DependencyValues
                .live[
                    StepDependencyKey
                        .self
                ]
            ==
            1
        )


        #expect(
            DependencyValues
                .preview[
                    StepDependencyKey
                        .self
                ]
            ==
            2
        )


        #expect(
            DependencyValues
                .test[
                    StepDependencyKey
                        .self
                ]
            ==
            3
        )
    }


    @Test
    func dependencyOverrideIsScoped() {

        let result =
            withDependencies(
                {
                    values in

                    values.testStep =
                        42
                }
            ) {

                DependencyValues
                    .current
                    .testStep
            }


        #expect(
            result
            ==
            42
        )


        #expect(
            DependencyValues
                .current
                .testStep
            ==
            1
        )
    }


    @Test
    func featureHostUsesCapturedDependencySnapshot() {

        let host =
            withDependencies(
                {
                    values in

                    values.testStep =
                        5
                }
            ) {

                FeatureHost<CounterFeature>(
                    service:
                        CounterFeature
                            .Service()
                )
            }


        host
            .send(
                .increment
            )


        host
            .send(
                .increment
            )


        #expect(
            host.state.value
            ==
            10
        )
    }
}

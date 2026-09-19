//
//  FeatureHost.swift
//  AppFoundation
//

import Foundation


// MARK: - Feature Host

/*
 FeatureHost 是 Feature definition
 对应的实际 runtime instance。


 FeatureHost owns：

 - State
 - Service
 - dependency snapshot
 - structured Tasks
 - cancellation


 FeatureHost 不知道任何：

 - UI framework
 - navigation
 - scene
 - product domain
 */

@MainActor
public final class FeatureHost<F>
where F: Feature {

    // MARK: - Running Task

    private typealias RunningTask =
        Task<Void, Never>


    // MARK: - Runtime

    public let state:
        F.State


    public let service:
        F.Service


    // MARK: - Dependencies

    /*
     Host 创建时捕获 dependency environment。

     后续 Action 和 async work
     都重新进入同一 snapshot。
     */

    private let dependencies:
        DependencyValues


    // MARK: - Identified Tasks

    private var identifiedTasks:
        [
            FeatureTaskID:
                [
                    UUID:
                        RunningTask
                ]
        ] =
            [:]


    // MARK: - Anonymous Tasks

    private var anonymousTasks:
        [
            UUID:
                RunningTask
        ] =
            [:]


    // MARK: - Init

    public init(
        state:
            F.State,
        service:
            F.Service
    ) {

        self.state =
            state


        self.service =
            service


        self.dependencies =
            DependencyValues
                .current
    }


    public convenience init(
        service:
            F.Service
    ) {

        self.init(
            state:
                F.makeInitialState(),
            service:
                service
        )
    }


    // MARK: - Send

    public func send(
        _ action:
            F.Action
    ) {

        let tasks =
            withDependencies(
                dependencies
            ) {

                service
                    .handle(
                        action,
                        state:
                            state
                    )
            }


        execute(
            tasks
        )
    }


    // MARK: - Execute

    private func execute(
        _ tasks:
            [FeatureTask<F.Action>]
    ) {

        for task
        in tasks {

            execute(
                task
            )
        }
    }


    private func execute(
        _ task:
            FeatureTask<F.Action>
    ) {

        switch task.kind {

        // MARK: Run

        case .run(
            let id,
            let cancelInFlight,
            let operation
        ):

            if let id,
               cancelInFlight {

                cancel(
                    id:
                        id
                )
            }


            let token =
                UUID()


            let dependencies =
                self.dependencies


            let runningTask =
                Task {
                    @MainActor
                    [weak self]
                    in

                    await withDependencies(
                        dependencies
                    ) {

                        await operation {
                            [weak self]
                            action in

                            // Cancellation is cooperative; revoke the callback as well.
                            guard let self, self.isRunning(token: token, id: id) else {
                                return
                            }
                            self.send(action)
                        }
                    }


                    self?
                        .taskDidFinish(
                            token:
                                token,
                            id:
                                id
                        )
                }


            if let id {

                identifiedTasks[
                    id,
                    default:
                        [:]
                ][
                    token
                ] =
                    runningTask

            } else {

                anonymousTasks[
                    token
                ] =
                    runningTask
            }


        // MARK: Cancel

        case .cancel(
            let id
        ):

            cancel(
                id:
                    id
            )
        }
    }


    // MARK: - Cancel Identified

    public func cancel(
        id:
            FeatureTaskID
    ) {

        guard
            let tasks =
                identifiedTasks
                    .removeValue(
                        forKey:
                            id
                    )
        else {

            return
        }


        for task
        in tasks.values {

            task.cancel()
        }
    }


    // MARK: - Cancel All

    public func cancelAll() {

        for tasks
        in identifiedTasks.values {

            for task
            in tasks.values {

                task.cancel()
            }
        }


        for task
        in anonymousTasks.values {

            task.cancel()
        }


        identifiedTasks
            .removeAll()


        anonymousTasks
            .removeAll()
    }


    private func isRunning(token: UUID, id: FeatureTaskID?) -> Bool {
        if let id {
            return identifiedTasks[id]?[token] != nil
        }
        return anonymousTasks[token] != nil
    }

    // MARK: - Completion

    private func taskDidFinish(
        token:
            UUID,
        id:
            FeatureTaskID?
    ) {

        if let id {

            identifiedTasks[
                id
            ]?[
                token
            ] =
                nil


            if identifiedTasks[
                id
            ]?
                .isEmpty
                ==
                true {

                identifiedTasks[
                    id
                ] =
                    nil
            }

        } else {

            anonymousTasks[
                token
            ] =
                nil
        }
    }


    // MARK: - Deinit

    deinit {

        for tasks
        in identifiedTasks.values {

            for task
            in tasks.values {

                task.cancel()
            }
        }


        for task
        in anonymousTasks.values {

            task.cancel()
        }
    }
}

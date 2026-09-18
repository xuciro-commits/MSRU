//
//  FeatureHost.swift
//  MSRU
//

import Foundation


@MainActor
final class FeatureHost<F: Feature> {

    private typealias RunningTask =
        Task<Void, Never>


    // MARK: - Runtime

    let state:
        F.State


    let service:
        F.Service


    /*
     Feature 创建时捕获自己的 dependency environment。

     后续 Action / FeatureTask 即使由不同 Task 触发，
     都重新进入同一套 dependency scope。
     */

    private let dependencies:
        DependencyValues


    // MARK: - Tasks

    private var identifiedTasks:
        [
            FeatureTaskID:
                [
                    UUID:
                        RunningTask
                ]
        ] = [:]


    private var anonymousTasks:
        [
            UUID:
                RunningTask
        ] = [:]


    // MARK: - Init

    init(
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


    convenience init(
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


    // MARK: - Deinit

    deinit {

        /*
         Feature runtime 销毁时，
         不允许 effect 继续悬挂。
         */

        for taskGroup
            in identifiedTasks.values {

            for task
                in taskGroup.values {

                task.cancel()
            }
        }


        for task
            in anonymousTasks.values {

            task.cancel()
        }
    }


    // MARK: - Send

    func send(
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


        for task in tasks {

            execute(
                task
            )
        }
    }


    // MARK: - Cancel All

    func cancelAll() {

        for taskGroup
            in identifiedTasks.values {

            for task
                in taskGroup.values {

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


    // MARK: - Execute

    private func execute(
        _ featureTask:
            FeatureTask<F.Action>
    ) {

        switch featureTask.kind {

        // MARK: Cancel

        case .cancel(
            let id
        ):

            cancel(
                id:
                    id
            )


        // MARK: Run

        case .run(
            let id,
            let cancelInFlight,
            let priority,
            let operation
        ):

            if
                let id,
                cancelInFlight {

                cancel(
                    id:
                        id
                )
            }


            let token =
                UUID()


            let dependencies =
                dependencies


            let task =
                Task(
                    priority:
                        priority
                ) {
                    [weak self]
                    in

                    guard
                        let self
                    else {

                        return
                    }


                    await withDependencies(
                        dependencies
                    ) {

                        await operation {
                            [weak self]
                            action in

                            self?
                                .send(
                                    action
                                )
                        }
                    }


                    self.finishTask(
                        id:
                            id,
                        token:
                            token
                    )
                }


            register(
                task:
                    task,
                id:
                    id,
                token:
                    token
            )
        }
    }


    // MARK: - Register

    private func register(
        task:
            RunningTask,
        id:
            FeatureTaskID?,
        token:
            UUID
    ) {

        if let id {

            identifiedTasks[
                id,
                default:
                    [:]
            ][
                token
            ] =
                task


            return
        }


        anonymousTasks[
            token
        ] =
            task
    }


    // MARK: - Cancel ID

    private func cancel(
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


    // MARK: - Finish

    private func finishTask(
        id:
            FeatureTaskID?,
        token:
            UUID
    ) {

        guard
            let id
        else {

            anonymousTasks[
                token
            ] = nil


            return
        }


        guard
            var tasks =
                identifiedTasks[
                    id
                ]
        else {

            return
        }


        tasks[
            token
        ] = nil


        if tasks.isEmpty {

            identifiedTasks[
                id
            ] = nil

        } else {

            identifiedTasks[
                id
            ] =
                tasks
        }
    }
}

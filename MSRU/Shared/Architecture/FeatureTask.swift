//
//  FeatureTask.swift
//  MSRU
//

import Foundation


@MainActor
struct FeatureTask<Action> {

    typealias Send =
        @MainActor (Action) -> Void


    typealias Operation =
        @MainActor (Send) async -> Void


    enum Kind {

        case run(
            id: String?,
            cancelInFlight: Bool,
            priority: TaskPriority?,
            operation: Operation
        )

        case cancel(
            id: String
        )
    }


    let kind:
        Kind


    // MARK: - Run

    static func run(
        id: String? = nil,
        cancelInFlight: Bool = false,
        priority: TaskPriority? = nil,
        operation:
            @escaping Operation
    ) -> Self {

        Self(
            kind:
                .run(
                    id:
                        id,
                    cancelInFlight:
                        cancelInFlight,
                    priority:
                        priority,
                    operation:
                        operation
                )
        )
    }


    // MARK: - Cancel

    static func cancel(
        id: String
    ) -> Self {

        Self(
            kind:
                .cancel(
                    id:
                        id
                )
        )
    }
}

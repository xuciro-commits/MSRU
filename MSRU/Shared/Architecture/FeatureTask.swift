//
//  FeatureTask.swift
//  MSRU
//

import Foundation


// MARK: - Feature Task ID

struct FeatureTaskID:
    Hashable,
    Sendable,
    CustomStringConvertible,
    ExpressibleByStringInterpolation {

    // MARK: Storage

    let rawValue:
        String


    // MARK: Init

    init(
        _ rawValue:
            String
    ) {

        self.rawValue =
            rawValue
    }


    init(
        stringLiteral value:
            String
    ) {

        self.rawValue =
            value
    }


    init(
        stringInterpolation:
            StringInterpolation
    ) {

        self.rawValue =
            stringInterpolation
                .value
    }


    // MARK: Description

    var description:
        String {

        rawValue
    }


    // MARK: String Interpolation

    struct StringInterpolation:
        StringInterpolationProtocol {

        fileprivate var value:
            String


        init(
            literalCapacity:
                Int,
            interpolationCount:
                Int
        ) {

            var value =
                String()

            value
                .reserveCapacity(
                    literalCapacity
                )


            self.value =
                value
        }


        mutating func appendLiteral(
            _ literal:
                String
        ) {

            value
                .append(
                    literal
                )
        }


        mutating func appendInterpolation<T>(
            _ value:
                T
        ) {

            self.value
                .append(
                    String(
                        describing:
                            value
                    )
                )
        }
    }
}


// MARK: - Feature Task

@MainActor
struct FeatureTask<Action> {

    typealias Send =
        @MainActor (
            Action
        ) -> Void


    typealias Operation =
        @MainActor (
            Send
        ) async -> Void


    // MARK: Kind

    enum Kind {

        case run(
            id: FeatureTaskID?,
            cancelInFlight: Bool,
            priority: TaskPriority?,
            operation: Operation
        )

        case cancel(
            id: FeatureTaskID
        )
    }


    // MARK: Storage

    let kind:
        Kind


    // MARK: - Run

    static func run(
        id:
            FeatureTaskID? = nil,
        cancelInFlight:
            Bool = false,
        priority:
            TaskPriority? = nil,
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
        id:
            FeatureTaskID
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

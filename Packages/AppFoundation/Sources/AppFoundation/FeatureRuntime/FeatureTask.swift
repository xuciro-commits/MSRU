//
//  FeatureTask.swift
//  AppFoundation
//

import Foundation


// MARK: - Feature Task ID

/*
 FeatureTaskID 避免 runtime 使用裸 String
 表达 cancellation identity。

 同时支持：

     "request"

 和：

     "resource.\(id)"
 */

public struct FeatureTaskID:
    Hashable,
    Sendable,
    CustomStringConvertible,
    ExpressibleByStringLiteral,
    ExpressibleByStringInterpolation {

    // MARK: - Storage

    public let rawValue:
        String


    // MARK: - Init

    public init(
        _ rawValue:
            String
    ) {

        self.rawValue =
            rawValue
    }


    // MARK: - String Literal

    public init(
        stringLiteral value:
            String
    ) {

        self.rawValue =
            value
    }


    // MARK: - String Interpolation

    public struct StringInterpolation:
        StringInterpolationProtocol,
        Sendable {

        var value:
            String


        public init(
            literalCapacity:
                Int,
            interpolationCount:
                Int
        ) {

            var value =
                String()

            value.reserveCapacity(
                literalCapacity
                +
                interpolationCount * 8
            )

            self.value =
                value
        }


        public mutating func appendLiteral(
            _ literal:
                String
        ) {

            value
                .append(
                    contentsOf:
                        literal
                )
        }


        public mutating func appendInterpolation<T>(
            _ interpolation:
                T
        ) {

            value
                .append(
                    contentsOf:
                        String(
                            describing:
                                interpolation
                        )
                )
        }
    }


    public init(
        stringInterpolation:
            StringInterpolation
    ) {

        self.rawValue =
            stringInterpolation
                .value
    }


    // MARK: - Description

    public var description:
        String {

        rawValue
    }
}


// MARK: - Feature Task

/*
 FeatureTask 是 Feature Service
 返回给 Runtime 的 structured work description。


 Service 可以描述：

 - run async work
 - identified work
 - cancel-in-flight behavior
 - cancellation


 Service 自己不创建 unmanaged Task。
 */

public struct FeatureTask<Action> {

    // MARK: - Send

    public typealias Send =
        @MainActor (
            Action
        ) -> Void


    // MARK: - Operation

    public typealias Operation =
        @MainActor (
            _ send:
                @escaping Send
        ) async -> Void


    // MARK: - Internal Representation

    enum Kind {

        case run(
            id:
                FeatureTaskID?,
            cancelInFlight:
                Bool,
            operation:
                Operation
        )

        case cancel(
            id:
                FeatureTaskID
        )
    }


    let kind:
        Kind


    private init(
        kind:
            Kind
    ) {

        self.kind =
            kind
    }


    // MARK: - Run

    public static func run(
        id:
            FeatureTaskID? = nil,
        cancelInFlight:
            Bool = false,
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
                    operation:
                        operation
                )
        )
    }


    // MARK: - Cancel

    public static func cancel(
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

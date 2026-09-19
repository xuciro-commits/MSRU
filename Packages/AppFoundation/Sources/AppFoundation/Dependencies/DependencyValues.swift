//
//  DependencyValues.swift
//  AppFoundation
//

import Foundation


// MARK: - Dependency Values

/*
 DependencyValues 是一个轻量 typed dependency container。

 Foundation 不知道任何具体 dependency。

 Consumer 自己通过：

     DependencyKey
     +
     DependencyValues extension

 定义自己的 dependency surface。


 AppFoundation 永远不应该出现：

 - database-specific dependency
 - music dependency
 - hotel dependency
 - inventory dependency
 - networking vendor dependency
 */

public struct DependencyValues:
    @unchecked Sendable {

    // MARK: - Environment

    public let environment:
        DependencyEnvironment


    // MARK: - Storage

    private var storage:
        [
            ObjectIdentifier:
                Any
        ]


    // MARK: - Init

    public init(
        environment:
            DependencyEnvironment = .live
    ) {

        self.environment =
            environment


        self.storage =
            [:]
    }


    // MARK: - Standard Environments

    public static var live:
        Self {

        Self(
            environment:
                .live
        )
    }


    public static var preview:
        Self {

        Self(
            environment:
                .preview
        )
    }


    public static var test:
        Self {

        Self(
            environment:
                .test
        )
    }


    // MARK: - Current

    @MainActor
    public static var current:
        Self {

        DependencyContext
            .current
    }


    // MARK: - Typed Access

    @MainActor
    public subscript<Key>(
        key:
            Key.Type
    ) -> Key.Value
    where Key: DependencyKey {

        get {

            let identifier =
                ObjectIdentifier(
                    key
                )


            if let value =
                storage[
                    identifier
                ]
                as? Key.Value {

                return
                    value
            }


            switch environment {

            case .live:

                return
                    Key.liveValue


            case .preview:

                return
                    Key.previewValue


            case .test:

                return
                    Key.testValue
            }
        }


        set {

            storage[
                ObjectIdentifier(
                    key
                )
            ] =
                newValue
        }
    }
}


// MARK: - Dependency Context

/*
 TaskLocal 只负责传播 dependency context。

 FeatureHost 会另外捕获 snapshot，
 所以 Feature runtime 不依赖调用者之后
 恰好处于哪个 TaskLocal scope。
 */

enum DependencyContext {

    @TaskLocal
    static var current:
        DependencyValues =
            .live
}

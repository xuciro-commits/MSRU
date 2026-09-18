//
//  DependencyValues.swift
//  MSRU
//

import Foundation


struct DependencyValues:
    @unchecked Sendable {

    // MARK: - Environment

    let environment:
        DependencyEnvironment


    // MARK: - Overrides

    /*
     Value 可能是：

     - Sendable value
     - @MainActor reference
     - protocol existential

     DependencyValues 自身会沿 TaskLocal 传播，
     但具体依赖始终由对应的 actor contract 约束。

     因此这里明确使用 @unchecked Sendable，
     而不是要求整个应用依赖图全部 Sendable。
     */

    private var storage:
        [
            ObjectIdentifier:
                Any
        ]


    // MARK: - Init

    init(
        environment:
            DependencyEnvironment = .live
    ) {

        self.environment =
            environment

        self.storage =
            [:]
    }


    // MARK: - Standard Environments

    static var live:
        Self {

        Self(
            environment:
                .live
        )
    }


    static var preview:
        Self {

        Self(
            environment:
                .preview
        )
    }


    static var test:
        Self {

        Self(
            environment:
                .test
        )
    }


    // MARK: - Current

    @MainActor
    static var current:
        Self {

        DependencyContext
            .current
    }


    // MARK: - Key Access

    @MainActor
    subscript<Key>(
        key:
            Key.Type
    ) -> Key.Value
    where Key: DependencyKey {

        get {

            let identifier =
                ObjectIdentifier(
                    key
                )


            if
                let value =
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


// MARK: - Task Local Context

enum DependencyContext {

    /*
     Dependency context 随 structured concurrency
     自动向子 Task 传播。

     FeatureHost 仍然会显式恢复自己的 dependency snapshot，
     因而 Feature runtime 不依赖调用者碰巧处于哪个环境。
     */

    @TaskLocal
    static var current:
        DependencyValues =
            .live
}

//
//  Dependency.swift
//  MSRU
//

import Foundation


@MainActor
@propertyWrapper
struct Dependency<Value> {

    // MARK: - Override

    private enum Override {

        case none

        case value(
            Value
        )
    }


    // MARK: - Storage

    private let keyPath:
        KeyPath<
            DependencyValues,
            Value
        >


    /*
     创建 @Dependency 时捕获 dependency snapshot。

     这样 Service 创建完成后，
     它看到的 Application Dependencies 不会因为
     外部 TaskLocal 环境变化而漂移。
     */

    private let values:
        DependencyValues


    private var override:
        Override =
            .none


    // MARK: - Init

    init(
        _ keyPath:
            KeyPath<
                DependencyValues,
                Value
            >
    ) {

        self.keyPath =
            keyPath

        self.values =
            DependencyValues
                .current
    }


    // MARK: - Value

    var wrappedValue:
        Value {

        get {

            switch override {

            case .none:

                return
                    values[
                        keyPath:
                            keyPath
                    ]


            case .value(
                let value
            ):

                return
                    value
            }
        }


        set {

            override =
                .value(
                    newValue
                )
        }
    }
}

//
//  Dependency.swift
//  AppFoundation
//


// MARK: - Dependency

/*
 @Dependency 在创建时捕获 DependencyValues snapshot。

 这意味着某个 Service 创建以后，
 dependency environment 不会随着外部 TaskLocal
 后续变化而漂移。
 */

@MainActor
@propertyWrapper
public struct Dependency<Value> {

    // MARK: - Override

    private enum Override {

        case none

        case value(
            Value
        )
    }


    // MARK: - Key Path

    private let keyPath:
        KeyPath<
            DependencyValues,
            Value
        >


    // MARK: - Captured Values

    private let values:
        DependencyValues


    // MARK: - Local Override

    private var override:
        Override =
            .none


    // MARK: - Init

    public init(
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

    public var wrappedValue:
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

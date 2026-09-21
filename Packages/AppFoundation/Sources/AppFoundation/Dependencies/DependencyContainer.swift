//
//  DependencyContainer.swift
//  AppFoundation
//

import Foundation

// MARK: - Dependency Environment

public enum DependencyEnvironment: Sendable {
    case live
    case preview
    case test
}

// MARK: - Dependency Key

@MainActor
public protocol DependencyKey {
    associatedtype Value: Sendable
    static var liveValue: Value { get }
    static var previewValue: Value { get }
    static var testValue: Value { get }
}

// MARK: - Dependency Context

enum DependencyContext {
    @TaskLocal
    static var current: DependencyValues = .live
}

// MARK: - Dependency Values

public struct DependencyValues: Sendable {
    public let environment: DependencyEnvironment
    private var storage: [ObjectIdentifier: any Sendable]

    public init(environment: DependencyEnvironment = .live) {
        self.environment = environment
        self.storage = [:]
    }

    public static var live: Self {
        Self(environment: .live)
    }

    public static var preview: Self {
        Self(environment: .preview)
    }

    public static var test: Self {
        Self(environment: .test)
    }

    @MainActor
    public static var current: Self {
        DependencyContext.current
    }

    @MainActor
    public subscript<Key>(key: Key.Type) -> Key.Value where Key: DependencyKey {
        get {
            let identifier = ObjectIdentifier(key)
            if let value = storage[identifier] as? Key.Value {
                return value
            }
            switch environment {
            case .live:
                return Key.liveValue
            case .preview:
                return Key.previewValue
            case .test:
                return Key.testValue
            }
        }
        set {
            storage[ObjectIdentifier(key)] = newValue
        }
    }
}

// MARK: - Dependency Property Wrapper

@MainActor
@propertyWrapper
public struct Dependency<Value> {
    private enum Override {
        case none
        case value(Value)
    }

    private let keyPath: KeyPath<DependencyValues, Value>
    private let values: DependencyValues
    private var override: Override = .none

    public init(_ keyPath: KeyPath<DependencyValues, Value>) {
        self.keyPath = keyPath
        self.values = DependencyValues.current
    }

    public var wrappedValue: Value {
        get {
            switch override {
            case .none:
                return values[keyPath: keyPath]
            case .value(let value):
                return value
            }
        }
        set {
            override = .value(newValue)
        }
    }
}

// MARK: - With Dependencies Helpers

@MainActor
public func withDependencies<Result>(
    _ values: DependencyValues,
    operation: () throws -> Result
) rethrows -> Result {
    try DependencyContext.$current.withValue(values) {
        try operation()
    }
}

@MainActor
public func withDependencies<Result>(
    _ values: DependencyValues,
    operation: () async throws -> Result
) async rethrows -> Result {
    try await DependencyContext.$current.withValue(values) {
        try await operation()
    }
}

@MainActor
public func withDependencies<Result>(
    _ update: (inout DependencyValues) -> Void,
    operation: () throws -> Result
) rethrows -> Result {
    var values = DependencyValues.current
    update(&values)
    return try withDependencies(values, operation: operation)
}

@MainActor
public func withDependencies<Result>(
    _ update: (inout DependencyValues) -> Void,
    operation: () async throws -> Result
) async rethrows -> Result {
    var values = DependencyValues.current
    update(&values)
    return try await withDependencies(values, operation: operation)
}

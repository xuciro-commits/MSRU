//
//  FeatureRuntime.swift
//  AppFoundation
//

import Foundation

// MARK: - Feature Protocols

@MainActor
public protocol FeatureService {
    associatedtype State: AnyObject
    associatedtype Action
    func handle(_ action: Action, state: State) -> [FeatureTask<Action>]
}

@MainActor
public protocol Feature {
    associatedtype State: AnyObject
    associatedtype Action
    associatedtype Service: FeatureService where Service.State == State, Service.Action == Action
    static func makeInitialState() -> State
}

// MARK: - Feature Task ID

public struct FeatureTaskID:
    Hashable,
    Sendable,
    CustomStringConvertible,
    ExpressibleByStringLiteral,
    ExpressibleByStringInterpolation {

    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public struct StringInterpolation: StringInterpolationProtocol, Sendable {
        var value: String

        public init(literalCapacity: Int, interpolationCount: Int) {
            var value = String()
            value.reserveCapacity(literalCapacity + interpolationCount * 8)
            self.value = value
        }

        public mutating func appendLiteral(_ literal: String) {
            value.append(contentsOf: literal)
        }

        public mutating func appendInterpolation<T>(_ interpolation: T) {
            value.append(contentsOf: String(describing: interpolation))
        }
    }

    public init(stringInterpolation: StringInterpolation) {
        self.rawValue = stringInterpolation.value
    }

    public var description: String {
        rawValue
    }
}

// MARK: - Feature Task

public struct FeatureTask<Action> {
    public typealias Send = @MainActor (Action) -> Void
    public typealias Operation = @MainActor (_ send: @escaping Send) async -> Void

    enum Kind {
        case run(id: FeatureTaskID?, cancelInFlight: Bool, operation: Operation)
        case cancel(id: FeatureTaskID)
    }

    let kind: Kind

    private init(kind: Kind) {
        self.kind = kind
    }

    public static func run(
        id: FeatureTaskID? = nil,
        cancelInFlight: Bool = false,
        operation: @escaping Operation
    ) -> Self {
        Self(kind: .run(id: id, cancelInFlight: cancelInFlight, operation: operation))
    }

    public static func cancel(id: FeatureTaskID) -> Self {
        Self(kind: .cancel(id: id))
    }
}

// MARK: - Feature Host

@MainActor
public final class FeatureHost<F> where F: Feature {
    private typealias RunningTask = Task<Void, Never>

    public let state: F.State
    public let service: F.Service
    private let dependencies: DependencyValues
    private var identifiedTasks: [FeatureTaskID: [UUID: RunningTask]] = [:]
    private var anonymousTasks: [UUID: RunningTask] = [:]
    public private(set) var isStopped: Bool = false

    public init(state: F.State, service: F.Service) {
        self.state = state
        self.service = service
        self.dependencies = DependencyValues.current
    }

    public convenience init(service: F.Service) {
        self.init(state: F.makeInitialState(), service: service)
    }

    public func send(_ action: F.Action) {
        guard !isStopped else { return }
        let tasks = withDependencies(dependencies) {
            service.handle(action, state: state)
        }
        execute(tasks)
    }

    private func execute(_ tasks: [FeatureTask<F.Action>]) {
        for task in tasks {
            execute(task)
        }
    }

    private func execute(_ task: FeatureTask<F.Action>) {
        switch task.kind {
        case .run(let id, let cancelInFlight, let operation):
            if let id, cancelInFlight {
                cancel(id: id)
            }

            let token = UUID()
            let dependencies = self.dependencies

            let runningTask = Task { @MainActor [weak self] in
                await withDependencies(dependencies) {
                    await operation { [weak self] action in
                        guard let self, !self.isStopped, self.isRunning(token: token, id: id) else {
                            return
                        }
                        self.send(action)
                    }
                }
                self?.taskDidFinish(token: token, id: id)
            }

            if let id {
                identifiedTasks[id, default: [:]][token] = runningTask
            } else {
                anonymousTasks[token] = runningTask
            }

        case .cancel(let id):
            cancel(id: id)
        }
    }

    public func cancel(id: FeatureTaskID) {
        guard let tasks = identifiedTasks.removeValue(forKey: id) else { return }
        for task in tasks.values {
            task.cancel()
        }
    }

    public func cancelAll() {
        for tasks in identifiedTasks.values {
            for task in tasks.values {
                task.cancel()
            }
        }
        for task in anonymousTasks.values {
            task.cancel()
        }
        identifiedTasks.removeAll()
        anonymousTasks.removeAll()
    }

    public func stop() {
        guard !isStopped else { return }
        isStopped = true
        cancelAll()
    }

    private func isRunning(token: UUID, id: FeatureTaskID?) -> Bool {
        if let id {
            return identifiedTasks[id]?[token] != nil
        }
        return anonymousTasks[token] != nil
    }

    private func taskDidFinish(token: UUID, id: FeatureTaskID?) {
        if let id {
            identifiedTasks[id]?[token] = nil
            if identifiedTasks[id]?.isEmpty == true {
                identifiedTasks[id] = nil
            }
        } else {
            anonymousTasks[token] = nil
        }
    }

    deinit {
        for tasks in identifiedTasks.values {
            for task in tasks.values {
                task.cancel()
            }
        }
        for task in anonymousTasks.values {
            task.cancel()
        }
    }
}

//
//  ApplicationCommands.swift
//  MSRU
//

import Foundation
import AppFoundation

// MARK: - Command Handler Protocol

@MainActor
protocol ApplicationCommandHandler: AnyObject {
    @discardableResult
    func handle(_ command: ApplicationCommand) -> ApplicationCommandResult
}

// MARK: - Command Result & Rejection

nonisolated enum ApplicationCommandResult: Equatable, Sendable {
    case handled
    case scene(SceneID)
    case deferred
    case rejected(ApplicationCommandRejection)

    var isHandled: Bool {
        switch self {
        case .handled, .scene: return true
        case .deferred, .rejected: return false
        }
    }

    var isAccepted: Bool {
        switch self {
        case .handled, .scene, .deferred: return true
        case .rejected: return false
        }
    }

    var isDeferred: Bool {
        self == .deferred
    }

    var sceneID: SceneID? {
        switch self {
        case .scene(let sceneID): return sceneID
        case .handled, .deferred, .rejected: return nil
        }
    }

    var rejection: ApplicationCommandRejection? {
        switch self {
        case .rejected(let rejection): return rejection
        case .handled, .scene, .deferred: return nil
        }
    }
}

nonisolated enum ApplicationCommandRejection: Equatable, Sendable {
    case sceneNotFound(SceneID)
    case runtimeUnavailable
    case unsupported
}

// MARK: - Runtime Lifecycle Protocol

@MainActor
protocol ApplicationCommandRuntimeLifecycle: AnyObject {
    var canActivate: Bool { get }
    var isActive: Bool { get }
    @discardableResult
    func activate() -> [ApplicationCommandResult]
    func suspend()
}

// MARK: - Application Command Gate

@MainActor
final class ApplicationCommandGate: ApplicationCommandHandler {
    private enum State {
        case suspended
        case active
    }

    private var state: State
    private let downstream: any ApplicationCommandHandler
    private var pendingCommands: [ApplicationCommand] = []

    init(downstream: any ApplicationCommandHandler, startsActive: Bool = false) {
        self.downstream = downstream
        self.state = startsActive ? .active : .suspended
    }

    var isActive: Bool {
        switch state {
        case .active: return true
        case .suspended: return false
        }
    }

    var pendingCount: Int {
        pendingCommands.count
    }

    func handle(_ command: ApplicationCommand) -> ApplicationCommandResult {
        guard isActive else {
            pendingCommands.append(command)
            return .deferred
        }
        return downstream.handle(command)
    }

    @discardableResult
    func activate() -> [ApplicationCommandResult] {
        guard !isActive else { return [] }
        state = .active
        let commands = pendingCommands
        pendingCommands.removeAll(keepingCapacity: true)
        return commands.map { downstream.handle($0) }
    }

    func suspend() {
        state = .suspended
    }
}

// MARK: - Single Scene Command Handler & Runtime

@MainActor
final class SingleSceneApplicationCommandHandler: ApplicationCommandHandler {
    private weak var scene: (any ApplicationSceneRuntime)?

    var sceneID: SceneID? {
        scene?.id
    }

    var isAttached: Bool {
        scene != nil
    }

    func attach(_ scene: any ApplicationSceneRuntime) {
        self.scene = scene
    }

    func detach() {
        scene = nil
    }

    func handle(_ command: ApplicationCommand) -> ApplicationCommandResult {
        guard let scene else {
            return .rejected(.runtimeUnavailable)
        }

        switch command {
        case .route(let request):
            return handleRoute(request, scene: scene)
        case .openNewScene:
            return .rejected(.unsupported)
        case .activateScene(let sceneID):
            guard scene.id == sceneID else {
                return .rejected(.sceneNotFound(sceneID))
            }
            return .scene(scene.id)
        }
    }

    private func handleRoute(
        _ request: SceneRoutingRequest,
        scene: any ApplicationSceneRuntime
    ) -> ApplicationCommandResult {
        switch request.target {
        case .activeOrNew:
            scene.send(.navigate(request.route))
            return .scene(scene.id)
        case .scene(let requestedSceneID):
            guard requestedSceneID == scene.id else {
                return .rejected(.sceneNotFound(requestedSceneID))
            }
            scene.send(.navigate(request.route))
            return .scene(scene.id)
        case .new:
            return .rejected(.unsupported)
        }
    }
}

@MainActor
final class SingleSceneApplicationCommandRuntime: ApplicationCommandRuntimeLifecycle {
    private let handler: SingleSceneApplicationCommandHandler
    private let gate: ApplicationCommandGate

    init() {
        let handler = SingleSceneApplicationCommandHandler()
        let gate = ApplicationCommandGate(downstream: handler)
        self.handler = handler
        self.gate = gate
    }

    var canActivate: Bool {
        handler.isAttached
    }

    var isActive: Bool {
        gate.isActive && handler.isAttached
    }

    var sceneID: SceneID? {
        handler.sceneID
    }

    var pendingCommandCount: Int {
        gate.pendingCount
    }

    @discardableResult
    func send(_ command: ApplicationCommand) -> ApplicationCommandResult {
        gate.handle(command)
    }

    @discardableResult
    func send(_ commands: [ApplicationCommand]) -> [ApplicationCommandResult] {
        commands.map { gate.handle($0) }
    }

    func attach(_ scene: any ApplicationSceneRuntime) {
        handler.attach(scene)
    }

    @discardableResult
    func activate() -> [ApplicationCommandResult] {
        guard canActivate else { return [] }
        return gate.activate()
    }

    func suspend() {
        gate.suspend()
    }

    func detach() {
        suspend()
        handler.detach()
    }
}

// MARK: - Multi Scene Command Handler & Runtime

@MainActor
final class MultiSceneApplicationCommandHandler: ApplicationCommandHandler {
    private let runtime: any ApplicationMultiSceneRuntime

    init(runtime: any ApplicationMultiSceneRuntime) {
        self.runtime = runtime
    }

    func handle(_ command: ApplicationCommand) -> ApplicationCommandResult {
        switch command {
        case .route(let request):
            return handleRoute(request)
        case .openNewScene(let route):
            let sceneID = runtime.openNewScene(route: route)
            return .scene(sceneID)
        case .activateScene(let sceneID):
            guard runtime.activateScene(sceneID) else {
                return .rejected(.sceneNotFound(sceneID))
            }
            return .scene(sceneID)
        }
    }

    private func handleRoute(_ request: SceneRoutingRequest) -> ApplicationCommandResult {
        if let sceneID = runtime.route(request) {
            return .scene(sceneID)
        }

        switch request.target {
        case .scene(let sceneID):
            return .rejected(.sceneNotFound(sceneID))
        case .activeOrNew, .new:
            return .rejected(.unsupported)
        }
    }
}

@MainActor
final class MultiSceneApplicationCommandRuntime: ApplicationCommandRuntimeLifecycle {
    private let gate: ApplicationCommandGate

    init(runtime: any ApplicationMultiSceneRuntime, startsActive: Bool = false) {
        let handler = MultiSceneApplicationCommandHandler(runtime: runtime)
        let gate = ApplicationCommandGate(downstream: handler, startsActive: startsActive)
        self.gate = gate
    }

    var canActivate: Bool {
        true
    }

    var isActive: Bool {
        gate.isActive
    }

    var pendingCommandCount: Int {
        gate.pendingCount
    }

    @discardableResult
    func send(_ command: ApplicationCommand) -> ApplicationCommandResult {
        gate.handle(command)
    }

    @discardableResult
    func send(_ commands: [ApplicationCommand]) -> [ApplicationCommandResult] {
        commands.map { gate.handle($0) }
    }

    @discardableResult
    func activate() -> [ApplicationCommandResult] {
        gate.activate()
    }

    func suspend() {
        gate.suspend()
    }
}

// MARK: - Command Sources

protocol ApplicationCommandSource {
    associatedtype Input
    nonisolated func command(from input: Input) -> ApplicationCommand?
}

nonisolated struct SceneRouteURLCommandSource: ApplicationCommandSource, Sendable {
    typealias Input = URL

    private let codec: SceneRouteURLCodec
    private let target: SceneRoutingTarget

    init(codec: SceneRouteURLCodec, target: SceneRoutingTarget = .activeOrNew) {
        self.codec = codec
        self.target = target
    }

    init(scheme: String, target: SceneRoutingTarget = .activeOrNew) {
        self.codec = SceneRouteURLCodec(scheme: scheme)
        self.target = target
    }

    func command(from url: URL) -> ApplicationCommand? {
        guard let route = codec.decode(url) else {
            return nil
        }
        return .open(route, target: target)
    }
}

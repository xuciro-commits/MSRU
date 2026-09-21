//
//  ApplicationLifecycleRuntime.swift
//  MSRU
//

import Foundation

// MARK: - Application Lifecycle Phase

nonisolated enum ApplicationLifecyclePhase: Equatable, Sendable {
    case initialized
    case bootstrapping
    case ready
    case suspended
    case terminated
}

// MARK: - Lifecycle Transition Result

nonisolated enum ApplicationLifecycleTransitionBlock: Equatable, Sendable {
    case bootstrapNotStarted
    case commandRuntimeUnavailable
    case terminated
}

nonisolated enum ApplicationLifecycleTransitionResult: Equatable, Sendable {
    case transitioned(to: ApplicationLifecyclePhase, commandResults: [ApplicationCommandResult])
    case unchanged(ApplicationLifecyclePhase)
    case blocked(ApplicationLifecycleTransitionBlock)
}

// MARK: - Application Lifecycle Runtime

@MainActor
final class ApplicationLifecycleRuntime {
    private(set) var phase: ApplicationLifecyclePhase = .initialized
    private let commandRuntime: any ApplicationCommandRuntimeLifecycle

    init(commandRuntime: any ApplicationCommandRuntimeLifecycle) {
        self.commandRuntime = commandRuntime
    }

    @discardableResult
    func beginBootstrap() -> ApplicationLifecycleTransitionResult {
        switch phase {
        case .initialized:
            phase = .bootstrapping
            return .transitioned(to: .bootstrapping, commandResults: [])
        case .bootstrapping, .ready, .suspended:
            return .unchanged(phase)
        case .terminated:
            return .blocked(.terminated)
        }
    }

    @discardableResult
    func markReady() -> ApplicationLifecycleTransitionResult {
        switch phase {
        case .initialized:
            return .blocked(.bootstrapNotStarted)
        case .bootstrapping:
            guard commandRuntime.canActivate else {
                return .blocked(.commandRuntimeUnavailable)
            }
            let commandResults = commandRuntime.activate()
            phase = .ready
            return .transitioned(to: .ready, commandResults: commandResults)
        case .ready:
            return .unchanged(.ready)
        case .suspended:
            return .unchanged(.suspended)
        case .terminated:
            return .blocked(.terminated)
        }
    }

    @discardableResult
    func suspend() -> ApplicationLifecycleTransitionResult {
        switch phase {
        case .ready:
            commandRuntime.suspend()
            phase = .suspended
            return .transitioned(to: .suspended, commandResults: [])
        case .suspended:
            return .unchanged(.suspended)
        case .initialized, .bootstrapping:
            return .unchanged(phase)
        case .terminated:
            return .blocked(.terminated)
        }
    }

    @discardableResult
    func resume() -> ApplicationLifecycleTransitionResult {
        switch phase {
        case .suspended:
            guard commandRuntime.canActivate else {
                return .blocked(.commandRuntimeUnavailable)
            }
            let commandResults = commandRuntime.activate()
            phase = .ready
            return .transitioned(to: .ready, commandResults: commandResults)
        case .ready:
            return .unchanged(.ready)
        case .initialized:
            return .blocked(.bootstrapNotStarted)
        case .bootstrapping:
            return .unchanged(.bootstrapping)
        case .terminated:
            return .blocked(.terminated)
        }
    }

    @discardableResult
    func terminate() -> ApplicationLifecycleTransitionResult {
        guard phase != .terminated else {
            return .unchanged(.terminated)
        }
        commandRuntime.suspend()
        phase = .terminated
        return .transitioned(to: .terminated, commandResults: [])
    }
}

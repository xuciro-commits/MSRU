//
//  DependencyKey.swift
//  AppFoundation
//


// MARK: - Dependency Environment

public enum DependencyEnvironment:
    Sendable {

    case live

    case preview

    case test
}


// MARK: - Dependency Key

/*
 DependencyKey 明确要求三个环境。

 preview / test 不自动 fallback 到 live。

 这样 framework consumer 必须主动决定：

 - production behavior
 - preview behavior
 - test behavior

 避免测试或 Preview 意外使用真实服务。
 */

@MainActor
public protocol DependencyKey {

    associatedtype Value:
        Sendable


    static var liveValue:
        Value { get }


    static var previewValue:
        Value { get }


    static var testValue:
        Value { get }
}

//
//  DependencyKey.swift
//  MSRU
//

import Foundation


// MARK: - Environment

enum DependencyEnvironment:
    Sendable {

    case live

    case preview

    case test
}


// MARK: - Dependency Key

/*
 每个 DependencyKey 必须明确声明：

 - liveValue
 - previewValue
 - testValue

 Preview / Test 禁止隐式 fallback 到 Live。

 这样新增依赖时，如果开发者忘记提供
 安全的 Preview / Test implementation，
 编译器会直接阻止它进入 Runtime。
 */

@MainActor
protocol DependencyKey {

    associatedtype Value


    static var liveValue:
        Value {
        get
    }


    static var previewValue:
        Value {
        get
    }


    static var testValue:
        Value {
        get
    }
}

//
//  Feature.swift
//  MSRU
//

import Foundation


// MARK: - Feature Service

/*
 FeatureService 是 Feature 的同步决策层。

 职责：

 Action
   ↓
 Service.handle
   ↓
 mutate State synchronously
   ↓
 return FeatureTask<Action>

 Service 本身不拥有任务生命周期。
 任务执行、取消、替换都交给 FeatureHost。
 */

@MainActor
protocol FeatureService {

    associatedtype State:
        AnyObject

    associatedtype Action


    func handle(
        _ action:
            Action,
        state:
            State
    ) -> [FeatureTask<Action>]
}


// MARK: - Feature

/*
 Feature 是应用能力的静态定义。

 Feature 本身不是 runtime instance。

 FeatureHost<F> 才是某个运行时 scope
 中真正存在的 Feature 实例。
 */

@MainActor
protocol Feature {

    associatedtype State:
        AnyObject

    associatedtype Action

    associatedtype Service:
        FeatureService
        where
            Service.State == State,
            Service.Action == Action


    static func makeInitialState()
        -> State
}

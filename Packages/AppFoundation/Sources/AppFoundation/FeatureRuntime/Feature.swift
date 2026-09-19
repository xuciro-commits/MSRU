//
//  Feature.swift
//  AppFoundation
//


// MARK: - Feature Service

/*
 FeatureService：

 Action
   ↓
 Service
   ↓
 synchronous State mutation
   +
 structured FeatureTask


 Service 不拥有 Feature lifecycle。
 FeatureHost 才拥有 runtime lifecycle。
 */

@MainActor
public protocol FeatureService {

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
 Feature 只是静态 definition。

 Feature != runtime。

 Runtime state / service / tasks
 由 FeatureHost 持有。
 */

@MainActor
public protocol Feature {

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

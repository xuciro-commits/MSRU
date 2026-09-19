//
//  ApplicationFeature.swift
//  AppFoundation
//


// MARK: - Application Feature

/*
 ApplicationFeature 表示：

 一个 Feature 除了自己的 runtime 行为以外，
 还可以向 Application 声明结构贡献。


 它不决定：

 - App 怎么渲染 Sidebar
 - Window 怎么创建
 - Command 怎么执行
 - Route 怎么呈现


 它只描述自己的 Application-facing metadata。
 */

public protocol ApplicationFeature {

    associatedtype Route:
        Hashable & Sendable


    static var contributions:
        FeatureContribution<Route> {
        get
    }
}


// MARK: - Default

public extension ApplicationFeature {

    static var contributions:
        FeatureContribution<Route> {

        FeatureContribution()
    }
}

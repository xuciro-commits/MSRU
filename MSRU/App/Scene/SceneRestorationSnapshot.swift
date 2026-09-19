//
//  SceneRestorationSnapshot.swift
//  MSRU
//

import Foundation
import AppFoundation


// MARK: - Scene Restoration Snapshot

/*
 Restoration 保存的是 Scene 的语义状态。

 它不是 Runtime Serialization。

 Snapshot 不允许包含：

 - ApplicationModel
 - DependencyValues
 - FeatureHost
 - Services
 - Tasks
 - AVPlayer
 - Network state
 - Store object graph

 Runtime 在恢复 Scene 时重新创建，
 Application Scope 重新连接。
 */

nonisolated struct SceneRestorationSnapshot:
    Codable,
    Equatable,
    Sendable {

    // MARK: - Version

    static let currentVersion =
        1


    let version:
        Int


    // MARK: - Identity

    let sceneID:
        SceneID


    // MARK: - Navigation

    var section:
        SceneSection


    // MARK: - Presentation

    var isQueuePresented:
        Bool


    // MARK: - Init

    init(
        version:
            Int = Self.currentVersion,
        sceneID:
            SceneID,
        section:
            SceneSection,
        isQueuePresented:
            Bool
    ) {

        self.version =
            version


        self.sceneID =
            sceneID


        self.section =
            section


        self.isQueuePresented =
            isQueuePresented
    }


    // MARK: - Compatibility

    var isSupported:
        Bool {

        version
        ==
        Self.currentVersion
    }
}

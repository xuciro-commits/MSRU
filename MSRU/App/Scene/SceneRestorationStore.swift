import AppFoundation

//
//  SceneRestorationStore.swift
//  MSRU
//


// MARK: - Scene Restoration Store

/*
 SceneRestorationStore 是 Core 定义的 persistence port。

 它只认识：

 - SceneID
 - SceneRestorationSnapshot

 它不知道：

 - UserDefaults
 - SceneStorage
 - AppKit
 - UIKit
 - Window
 - View

 平台层决定真正如何保存。
 */

@MainActor
protocol SceneRestorationStore:
    AnyObject {

    func loadSnapshots()
        -> [SceneRestorationSnapshot]


    func save(
        _ snapshot:
            SceneRestorationSnapshot
    )


    func remove(
        sceneID:
            SceneID
    )
}

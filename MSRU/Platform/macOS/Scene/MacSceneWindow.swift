//
//  MacSceneWindow.swift
//  MSRU
//

#if os(macOS)


// MARK: - Scene Window

/*
 MacSceneWindow 是 Coordinator
 与具体 Window implementation 之间的边界。

 Coordinator 只关心：

 - 这个 Window 属于哪个 Scene
 - 激活 Window
 - 获取 Scene restoration snapshot

 它不关心：

 - NSWindow
 - Toolbar
 - SplitView
 - SwiftUI Hosting
 */

@MainActor
protocol MacSceneWindow:
    AnyObject {

    var sceneID:
        SceneID { get }


    func activate()


    func restorationSnapshot()
        -> SceneRestorationSnapshot
}


// MARK: - Factory

@MainActor
protocol MacSceneWindowFactory:
    AnyObject {

    func makeWindow(
        scene:
            SceneModel,
        onSnapshotChange:
            @escaping @MainActor (
                SceneRestorationSnapshot
            ) -> Void,
        onSceneClosed:
            @escaping @MainActor (
                SceneID
            ) -> Void
    ) -> any MacSceneWindow
}

#endif

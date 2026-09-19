//
//  MacSceneWindow.swift
//  MSRU
//

#if os(macOS)


// MARK: - Scene Window

@MainActor
protocol MacSceneWindow:
    AnyObject {

    var sceneID:
        SceneID { get }


    /*
     用于 external routing 判断
     当前真正的 key Window。

     Test doubles 可以使用默认 false。
     */

    var isActive:
        Bool { get }


    func activate()


    func restorationSnapshot()
        -> SceneRestorationSnapshot
}


// MARK: - Default Capability

extension MacSceneWindow {

    var isActive:
        Bool {

        false
    }
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

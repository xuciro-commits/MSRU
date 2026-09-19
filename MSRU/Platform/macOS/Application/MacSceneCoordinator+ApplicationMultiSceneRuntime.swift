//
//  MacSceneCoordinator+ApplicationMultiSceneRuntime.swift
//  MSRU
//

#if os(macOS)


// MARK: - Application Multi Scene Runtime

/*
 MacSceneCoordinator 已经天然实现：

 - route
 - openNewScene
 - activateScene


 这里只声明 capability conformance。

 不添加 macOS-specific command semantics。
 */

extension MacSceneCoordinator:
    ApplicationMultiSceneRuntime {}

#endif

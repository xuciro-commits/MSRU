import AppFoundation

//
//  ApplicationCommandHandler.swift
//  MSRU
//


// MARK: - Application Command Handler

/*
 ApplicationCommandHandler 是 Application layer
 与具体 runtime 之间的 capability boundary。

 Platform entry points 以后只需要知道：

     any ApplicationCommandHandler

 而不需要知道：

 - MacSceneCoordinator
 - NSWindow
 - SceneModel
 - SwiftUI WindowGroup


 v1 是同步 semantic dispatch。

 Future async work 不应该偷偷塞进这里；
 真正需要 structured concurrency 时，
 再显式引入 ApplicationTask / async command contract。
 */

@MainActor
protocol ApplicationCommandHandler:
    AnyObject {

    @discardableResult
    func handle(
        _ command:
            ApplicationCommand
    ) -> ApplicationCommandResult
}

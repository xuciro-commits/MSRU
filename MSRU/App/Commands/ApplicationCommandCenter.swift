import AppFoundation

//
//  ApplicationCommandCenter.swift
//  MSRU
//


// MARK: - Application Command Center

/*
 ApplicationCommandCenter 是整个 Application
 对 semantic command 的稳定入口。

 Callers:

 - AppDelegate
 - SwiftUI Commands
 - URL / Deep Link adapters
 - App Intents
 - Spotlight
 - Handoff
 - future plugins / automation

 都不应该直接知道：

 - MacSceneCoordinator
 - SceneModel
 - NSWindow
 - SwiftUI Navigation APIs


 CommandCenter 自己不实现 platform policy。

 它只负责：

     caller
        ↓
 ApplicationCommandCenter
        ↓
 ApplicationCommandHandler
        ↓
 platform / runtime implementation


 这样：

 - command definition 独立
 - dispatch boundary 独立
 - platform implementation 可替换
 - tests 不需要真正 Window
 */

@MainActor
final class ApplicationCommandCenter {

    // MARK: - Handler

    private let handler:
        any ApplicationCommandHandler


    // MARK: - Init

    init(
        handler:
            any ApplicationCommandHandler
    ) {

        self.handler =
            handler
    }


    // MARK: - Send

    @discardableResult
    func send(
        _ command:
            ApplicationCommand
    ) -> ApplicationCommandResult {

        handler
            .handle(
                command
            )
    }


    // MARK: - Batch Send

    /*
     External systems 经常一次交付多个 intent。

     典型例子：

     application(_:open:)
         -> [URL]

     CommandCenter 提供 batch dispatch，
     但不偷偷改变执行顺序。

     Results 与 commands 一一对应。
     */

    @discardableResult
    func send(
        _ commands:
            [ApplicationCommand]
    ) -> [ApplicationCommandResult] {

        commands
            .map {
                handler
                    .handle(
                        $0
                    )
            }
    }
}

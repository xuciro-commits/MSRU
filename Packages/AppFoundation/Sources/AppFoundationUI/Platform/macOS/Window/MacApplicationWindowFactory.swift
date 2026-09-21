//
//  MacApplicationWindowFactory.swift
//  AppFoundationUI
//

#if os(macOS)

import AppKit


// MARK: - macOS Application Window Factory

@MainActor
public enum MacApplicationWindowFactory {

    public static func makeWindow(
        contentViewController:
            NSViewController,
        configuration:
            MacWindowConfiguration
    ) -> NSWindow {

        let window =
            NSWindow(
                contentRect:
                    NSRect(
                        origin:
                            .zero,
                        size:
                            configuration
                                .initialSize
                    ),
                styleMask:
                    [
                        .titled,
                        .closable,
                        .miniaturizable,
                        .resizable,
                        .fullSizeContentView
                    ],
                backing:
                    .buffered,
                defer:
                    false
            )


        // 1. 设置 minSize / contentMinSize
        window.minSize =
            configuration
                .minimumSize

        window.contentMinSize =
            configuration
                .minimumSize


        // 2. 安装 contentViewController
        /*
         Install the content controller before toolbar creation.

         Native tracking separators require the tracked split view
         to already belong to the same window.
         */
        window.contentViewController =
            contentViewController


        // 3. 安装 toolbar / titlebar configuration
        window.title =
            configuration
                .title

        window.titleVisibility =
            configuration
                .titleVisibility

        window.titlebarAppearsTransparent =
            configuration
                .titlebarAppearsTransparent

        window.titlebarSeparatorStyle =
            configuration
                .titlebarSeparatorStyle

        window.toolbarStyle =
            configuration
                .toolbarStyle

        window.isReleasedWhenClosed =
            configuration
                .isReleasedWhenClosed

        window.collectionBehavior
            .insert(
                .fullScreenPrimary
            )


        // 4. 明确 setContentSize(initialSize) 保证 NSWindow 是 initial geometry 的唯一 owner。
        // 如果存在合法持久化恢复，则 restoration 优先；否则阻止 SwiftUI fitting size 压缩窗口
        let hasRestoredFrame =
            !window.frameAutosaveName.isEmpty
            && window.setFrameUsingName(window.frameAutosaveName)

        if !hasRestoredFrame {
            window.setContentSize(
                configuration
                    .initialSize
            )
        }


        // 5. center
        if configuration
            .centerOnCreation
            && !hasRestoredFrame {

            window.center()
        }


        return
            window
    }
}

#endif

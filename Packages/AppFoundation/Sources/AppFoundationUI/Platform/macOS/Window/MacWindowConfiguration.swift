//
//  MacWindowConfiguration.swift
//  AppFoundationUI
//

#if os(macOS)

import AppKit

// MARK: - macOS Window Configuration

/// Platform-level configuration for a standard application window.
@MainActor
public struct MacWindowConfiguration {
    public var title: String
    public var initialSize: NSSize
    public var minimumSize: NSSize
    public var toolbarStyle: NSWindow.ToolbarStyle
    public var titleVisibility: NSWindow.TitleVisibility
    public var titlebarAppearsTransparent: Bool
    public var titlebarSeparatorStyle: NSTitlebarSeparatorStyle
    public var centerOnCreation: Bool
    public var isReleasedWhenClosed: Bool

    public init(
        title: String,
        initialSize: NSSize = .init(width: 1200, height: 760),
        minimumSize: NSSize = .init(width: 900, height: 600),
        toolbarStyle: NSWindow.ToolbarStyle = .unified,
        titleVisibility: NSWindow.TitleVisibility = .hidden,
        titlebarAppearsTransparent: Bool = true,
        titlebarSeparatorStyle: NSTitlebarSeparatorStyle = .none,
        centerOnCreation: Bool = true,
        isReleasedWhenClosed: Bool = false
    ) {
        self.title = title
        self.initialSize = initialSize
        self.minimumSize = minimumSize
        self.toolbarStyle = toolbarStyle
        self.titleVisibility = titleVisibility
        self.titlebarAppearsTransparent = titlebarAppearsTransparent
        self.titlebarSeparatorStyle = titlebarSeparatorStyle
        self.centerOnCreation = centerOnCreation
        self.isReleasedWhenClosed = isReleasedWhenClosed
    }
}

// MARK: - macOS Application Window Factory

@MainActor
public enum MacApplicationWindowFactory {
    public static func makeWindow(
        contentViewController: NSViewController,
        configuration: MacWindowConfiguration
    ) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: configuration.initialSize),
            styleMask: [
                .titled,
                .closable,
                .miniaturizable,
                .resizable,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )

        // 1. 设置 minSize / contentMinSize
        window.minSize = configuration.minimumSize
        window.contentMinSize = configuration.minimumSize

        // 2. 安装 contentViewController
        window.contentViewController = contentViewController

        // 3. 安装 toolbar / titlebar configuration
        window.title = configuration.title
        window.titleVisibility = configuration.titleVisibility
        window.titlebarAppearsTransparent = configuration.titlebarAppearsTransparent
        window.titlebarSeparatorStyle = configuration.titlebarSeparatorStyle
        window.toolbarStyle = configuration.toolbarStyle
        window.isReleasedWhenClosed = configuration.isReleasedWhenClosed
        window.collectionBehavior.insert(.fullScreenPrimary)

        // 4. 明确 setContentSize(initialSize) 保证 NSWindow 是 initial geometry 的唯一 owner。
        let hasRestoredFrame = !window.frameAutosaveName.isEmpty && window.setFrameUsingName(window.frameAutosaveName)
        if !hasRestoredFrame {
            window.setContentSize(configuration.initialSize)
        }

        // 5. center
        if configuration.centerOnCreation && !hasRestoredFrame {
            window.center()
        }

        return window
    }
}

// MARK: - macOS Application Window Controller

@MainActor
public final class MacApplicationWindowController: NSWindowController {
    public let toolbarAdapter: MacToolbarAdapter?

    public init(
        contentViewController: NSViewController,
        configuration: MacWindowConfiguration,
        toolbarAdapter: MacToolbarAdapter? = nil
    ) {
        self.toolbarAdapter = toolbarAdapter
        let window = MacApplicationWindowFactory.makeWindow(
            contentViewController: contentViewController,
            configuration: configuration
        )
        super.init(window: window)
        toolbarAdapter?.install(on: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported.")
    }
}

#endif

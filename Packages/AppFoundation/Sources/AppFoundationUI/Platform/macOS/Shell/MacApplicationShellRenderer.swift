//
//  MacApplicationShellRenderer.swift
//  AppFoundationUI
//

#if os(macOS)

import AppKit
import SwiftUI


// MARK: - Context Rendering

/// Explicit policy for mapping semantic ContextPresentation
/// into the single native macOS context split region.
@MainActor
public struct MacApplicationContextRendering {
    public let region: MacSplitRegionConfiguration
    private let resolver: @MainActor (ResolvedApplicationShell) -> ResolvedContextPresentation?

    public init(
        region: MacSplitRegionConfiguration,
        resolve: @escaping @MainActor (ResolvedApplicationShell) -> ResolvedContextPresentation?
    ) {
        self.region = region
        self.resolver = resolve
    }

    func resolve(_ shell: ResolvedApplicationShell) -> ResolvedContextPresentation? {
        resolver(shell)
    }
}

// MARK: - Application Accessory Rendering

/// Explicit application-accessory selection.
@MainActor
public struct MacApplicationAccessoryRendering {
    public let height: CGFloat?
    private let resolver: @MainActor (ResolvedApplicationShell) -> ResolvedAccessoryPresentation?

    public init(
        height: CGFloat? = nil,
        resolve: @escaping @MainActor (ResolvedApplicationShell) -> ResolvedAccessoryPresentation?
    ) {
        self.height = height
        self.resolver = resolve
    }

    func resolve(_ shell: ResolvedApplicationShell) -> ResolvedAccessoryPresentation? {
        resolver(shell)
    }
}

// MARK: - Application Shell Configuration

@MainActor
public struct MacApplicationShellConfiguration {
    public let split: MacApplicationSplitConfiguration
    public let context: MacApplicationContextRendering?
    public let applicationAccessory: MacApplicationAccessoryRendering?
    public let rendersWorkspaceAccessory: Bool

    public init(
        split: MacApplicationSplitConfiguration,
        context: MacApplicationContextRendering? = nil,
        applicationAccessory: MacApplicationAccessoryRendering? = nil,
        rendersWorkspaceAccessory: Bool = true
    ) {
        self.split = split
        self.context = context
        self.applicationAccessory = applicationAccessory
        self.rendersWorkspaceAccessory = rendersWorkspaceAccessory
    }
}

// MARK: - macOS Application Shell Renderer

/// Native renderer for a fully resolved Application Shell.
///
/// Semantic ownership:
///
///     ApplicationShellResolver
///
/// Platform ownership:
///
///     MacApplicationShellRenderer
///
/// The renderer knows how to land already-resolved semantic
/// surfaces into native macOS presentation regions.
///
/// It has no knowledge of:
///
/// - application route types
/// - scene models
/// - playback
/// - product feature names
@MainActor
public final class MacApplicationShellRenderer {

    // MARK: - Native Shell

    public let splitController:
        MacApplicationSplitController


    // MARK: - Hosting

    private let workspaceHost:
        NSHostingController<AnyView>

    private let contextHost:
        NSHostingController<AnyView>?

    private let applicationAccessoryHost:
        MacSplitAccessoryHostingController<AnyView>?

    private let workspaceAccessoryHost:
        MacSplitAccessoryHostingController<AnyView>?


    // MARK: - Locale

    public var locale:
        Locale? {
        didSet {
            guard oldValue != locale else { return }
            if let lastShell {
                apply(lastShell)
            }
        }
    }

    private var lastShell:
        ResolvedApplicationShell?


    // MARK: - Configuration

    private let configuration:
        MacApplicationShellConfiguration


    // MARK: - Diagnostics / Current Resolution

    public private(set) var currentWorkspaceIdentity:
        WorkspaceIdentity?

    public private(set) var currentContextID:
        String?

    public private(set) var currentApplicationAccessoryID:
        String?

    public private(set) var currentWorkspaceAccessoryID:
        String?


    // MARK: - Init

    public init(
        navigationViewController:
            NSViewController,
        shell:
            ResolvedApplicationShell,
        configuration:
            MacApplicationShellConfiguration,
        locale:
            Locale? = nil,
        isContextPresented:
            Bool = true
    ) {

        self.locale =
            locale

        self.configuration =
            configuration


        let initialWorkspace =
            Self.wrapWorkspaceContent(
                shell
                    .workspace?
                    .content
                ??
                AnyView(
                    EmptyView()
                ),
                accessoryHeight:
                    configuration
                        .applicationAccessory?
                        .height,
                locale:
                    locale
            )


        let workspaceHost =
            MacHostingControllerFactory
                .make(
                    rootView:
                        initialWorkspace
                )


        self.workspaceHost =
            workspaceHost


        let splitController =
            MacApplicationSplitController(
                navigationViewController:
                    navigationViewController,
                workspaceViewController:
                    workspaceHost,
                configuration:
                    configuration
                        .split
            )


        self.splitController =
            splitController


        // ----------------------------------------------------
        // Context Host
        // ----------------------------------------------------

        if let contextConfiguration =
            configuration
                .context {

            let selectedContext =
                contextConfiguration
                    .resolve(
                        shell
                    )


            let contextHost =
                MacHostingControllerFactory
                    .make(
                        rootView:
                            selectedContext?
                                .content
                            ??
                            AnyView(
                                EmptyView()
                            )
                    )


            self.contextHost =
                contextHost


            splitController.installContext(
                viewController:
                    contextHost,
                configuration:
                    contextConfiguration
                        .region,
                isPresented:
                    isContextPresented
                    &&
                    selectedContext
                    !=
                    nil
            )

        } else {

            self.contextHost =
                nil
        }


        // ----------------------------------------------------
        // Application Accessory Host
        // ----------------------------------------------------

        if let accessoryConfiguration =
            configuration
                .applicationAccessory {

            let accessory =
                accessoryConfiguration
                    .resolve(
                        shell
                    )


            let host =
                MacSplitAccessoryHostingController(
                    rootView:
                        accessory?
                            .content
                        ??
                        AnyView(
                            EmptyView()
                        ),
                    height:
                        accessoryConfiguration
                            .height
                )


            self.applicationAccessoryHost =
                host


            splitController.addAccessory(
                host,
                to:
                    .workspace,
                edge:
                    .bottom
            )

        } else {

            self.applicationAccessoryHost =
                nil
        }


        // ----------------------------------------------------
        // Workspace Accessory Host
        // ----------------------------------------------------

        if configuration
            .rendersWorkspaceAccessory {

            let host =
                MacSplitAccessoryHostingController(
                    rootView:
                        shell
                            .workspace?
                            .workspaceAccessory?
                            .content
                        ??
                        AnyView(
                            EmptyView()
                        )
                )


            self.workspaceAccessoryHost =
                host


            splitController.addAccessory(
                host,
                to:
                    .workspace,
                edge:
                    .bottom
            )

        } else {

            self.workspaceAccessoryHost =
                nil
        }


        // All stored properties are initialized.
        apply(
            shell
        )
    }


    // MARK: - Resolution Update

    /// Applies a new semantic shell snapshot without rebuilding
    /// the native window/split hierarchy.
    ///
    /// Route changes therefore update the same native Workspace
    /// and Context hosts.
    public func apply(
        _ shell:
            ResolvedApplicationShell
    ) {

        lastShell =
            shell


        // ----------------------------------------------------
        // Workspace
        // ----------------------------------------------------

        currentWorkspaceIdentity =
            shell
                .workspace?
                .identity


        workspaceHost.rootView =
            wrapWorkspaceContent(
                shell
                    .workspace?
                    .content
                ??
                AnyView(
                    EmptyView()
                )
            )


        // ----------------------------------------------------
        // Context
        // ----------------------------------------------------

        if let contextConfiguration =
            configuration
                .context {

            let selectedContext =
                contextConfiguration
                    .resolve(
                        shell
                    )


            currentContextID =
                selectedContext?
                    .id


            contextHost?
                .rootView =
                    wrapWithLocale(
                        selectedContext?
                            .content
                        ??
                        AnyView(
                            EmptyView()
                        )
                    )


            if selectedContext == nil {

                splitController
                    .setContextPresented(
                        false
                    )
            }

        } else {

            currentContextID =
                nil
        }


        // ----------------------------------------------------
        // Application Accessory
        // ----------------------------------------------------

        if let accessoryConfiguration =
            configuration
                .applicationAccessory {

            let accessory =
                accessoryConfiguration
                    .resolve(
                        shell
                    )


            currentApplicationAccessoryID =
                accessory?
                    .id


            applicationAccessoryHost?
                .update(
                    rootView:
                        wrapWithLocale(
                            accessory?
                                .content
                            ??
                            AnyView(
                                EmptyView()
                            )
                        )
                )

        } else {

            currentApplicationAccessoryID =
                nil
        }


        // ----------------------------------------------------
        // Workspace Accessory
        // ----------------------------------------------------

        let workspaceAccessory =
            shell
                .workspace?
                .workspaceAccessory


        currentWorkspaceAccessoryID =
            workspaceAccessory?
                .id


        workspaceAccessoryHost?
            .update(
                rootView:
                    wrapWithLocale(
                        workspaceAccessory?
                            .content
                        ??
                        AnyView(
                            EmptyView()
                        )
                    )
            )
    }


    // MARK: - Workspace Wrapping Helper

    private static func wrapWorkspaceContent(
        _ content:
            AnyView,
        accessoryHeight:
            CGFloat?,
        locale:
            Locale?
    ) -> AnyView {

        var wrapped =
            content

        if let accessoryHeight,
           accessoryHeight > 0 {

            wrapped =
                AnyView(
                    wrapped
                        .safeAreaPadding(
                            .bottom,
                            accessoryHeight
                        )
                )
        }

        let localized =
            wrapWithLocale(
                wrapped,
                locale:
                    locale
            )

        return AnyView(
            WorkspaceSafeAreaContainer(
                content:
                    localized
            )
        )
    }
}

private struct WorkspaceSafeAreaContainer: View {

    let content:
        AnyView

    var body: some View {

        GeometryReader { proxy in

            content
                .frame(
                    width:
                        proxy.size.width,
                    height:
                        proxy.size.height
                )
                .environment(
                    \.workspaceSafeAreaInsets,
                    proxy.safeAreaInsets
                )
        }
    }
}

extension MacApplicationShellRenderer {

    private func wrapWorkspaceContent(
        _ content:
            AnyView
    ) -> AnyView {

        Self.wrapWorkspaceContent(
            content,
            accessoryHeight:
                configuration
                    .applicationAccessory?
                    .height,
            locale:
                locale
        )
    }


    // MARK: - Locale Wrapping Helper

    private static func wrapWithLocale(
        _ view:
            AnyView,
        locale:
            Locale?
    ) -> AnyView {

        if let locale {

            return AnyView(
                view.environment(
                    \.locale,
                    locale
                )
            )
        }

        return view
    }

    private func wrapWithLocale(
        _ view:
            AnyView
    ) -> AnyView {

        Self.wrapWithLocale(
            view,
            locale:
                locale
        )
    }


    // MARK: - Native Presentation

    public var isContextPresented:
        Bool {

        splitController
            .isContextPresented
    }


    public func setContextPresented(
        _ isPresented:
            Bool
    ) {

        splitController
            .setContextPresented(
                isPresented
            )
    }


    public func toggleContextPresentation() {

        splitController
            .toggleContextPresentation()
    }
}

#endif

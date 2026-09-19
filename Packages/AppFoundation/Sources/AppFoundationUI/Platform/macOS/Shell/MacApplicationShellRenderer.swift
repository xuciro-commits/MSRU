//
//  MacApplicationShellRenderer.swift
//  AppFoundationUI
//

#if os(macOS)

import AppKit
import SwiftUI


// MARK: - macOS Application Shell Renderer

/// Native renderer for a fully resolved Application Shell.
///
/// Semantic ownership:
///
///     ApplicationShellRuntime
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
        isContextPresented:
            Bool = true
    ) {

        self.configuration =
            configuration


        let initialWorkspace =
            shell
                .workspace?
                .content
            ??
            AnyView(
                EmptyView()
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
                        )
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

        // ----------------------------------------------------
        // Workspace
        // ----------------------------------------------------

        currentWorkspaceIdentity =
            shell
                .workspace?
                .identity


        workspaceHost.rootView =
            shell
                .workspace?
                .content
            ??
            AnyView(
                EmptyView()
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
                    selectedContext?
                        .content
                    ??
                    AnyView(
                        EmptyView()
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
                        accessory?
                            .content
                        ??
                        AnyView(
                            EmptyView()
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
                    workspaceAccessory?
                        .content
                    ??
                    AnyView(
                        EmptyView()
                    )
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

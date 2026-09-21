//
//  MacApplicationShellConfiguration.swift
//  AppFoundationUI
//

#if os(macOS)

import AppKit


// MARK: - Context Rendering

/// Explicit policy for mapping semantic ContextPresentation
/// into the single native macOS context split region.
///
/// The framework does not assume that `.inspector`,
/// `.preview`, `.activity`, or `.utility` automatically owns
/// the physical right-hand slot.
///
/// The application chooses the mapping.
@MainActor
public struct MacApplicationContextRendering {

    public let region:
        MacSplitRegionConfiguration

    private let resolver:
        @MainActor (
            ResolvedApplicationShell
        ) -> ResolvedContextPresentation?


    public init(
        region:
            MacSplitRegionConfiguration,
        resolve:
            @escaping @MainActor (
                ResolvedApplicationShell
            ) -> ResolvedContextPresentation?
    ) {

        self.region =
            region

        self.resolver =
            resolve
    }


    func resolve(
        _ shell:
            ResolvedApplicationShell
    ) -> ResolvedContextPresentation? {

        resolver(
            shell
        )
    }
}


// MARK: - Application Accessory Rendering

/// Explicit application-accessory selection.
///
/// Multiple semantic accessories may exist.
/// The platform renderer does not silently pick one.
@MainActor
public struct MacApplicationAccessoryRendering {

    public let height:
        CGFloat?

    private let resolver:
        @MainActor (
            ResolvedApplicationShell
        ) -> ResolvedAccessoryPresentation?


    public init(
        height:
            CGFloat? = nil,
        resolve:
            @escaping @MainActor (
                ResolvedApplicationShell
            ) -> ResolvedAccessoryPresentation?
    ) {

        self.height =
            height

        self.resolver =
            resolve
    }


    func resolve(
        _ shell:
            ResolvedApplicationShell
    ) -> ResolvedAccessoryPresentation? {

        resolver(
            shell
        )
    }
}


// MARK: - Application Shell Configuration

@MainActor
public struct MacApplicationShellConfiguration {

    public let split:
        MacApplicationSplitConfiguration

    public let context:
        MacApplicationContextRendering?

    public let applicationAccessory:
        MacApplicationAccessoryRendering?

    public let rendersWorkspaceAccessory:
        Bool


    public init(
        split:
            MacApplicationSplitConfiguration,
        context:
            MacApplicationContextRendering? = nil,
        applicationAccessory:
            MacApplicationAccessoryRendering? = nil,
        rendersWorkspaceAccessory:
            Bool = true
    ) {

        self.split =
            split

        self.context =
            context

        self.applicationAccessory =
            applicationAccessory

        self.rendersWorkspaceAccessory =
            rendersWorkspaceAccessory
    }
}

#endif

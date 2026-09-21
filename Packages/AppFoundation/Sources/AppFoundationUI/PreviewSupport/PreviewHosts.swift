//
//  PreviewHosts.swift
//  AppFoundationUI
//

import SwiftUI

// MARK: - Accessory Preview Host

/// Lightweight diagnostic renderer for accessory presentations.
@MainActor
public struct AccessoryPreviewHost<Context>: View {
    private let presentation: AccessoryPresentation<Context>
    private let context: Context

    public init(
        presentation: AccessoryPresentation<Context>,
        context: Context
    ) {
        self.presentation = presentation
        self.context = context
    }

    public var body: some View {
        HStack(spacing: 12) {
            Text(scopeTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Divider()
                .frame(height: 24)

            presentation
                .content(for: context)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var scopeTitle: String {
        switch presentation.scope {
        case .application: "Application"
        case .workspace: "Workspace"
        }
    }
}

// MARK: - Context Preview Host

/// Lightweight diagnostic renderer for developing contextual presentations.
@MainActor
public struct ContextPreviewHost<Context>: View {
    private let presentation: ContextPresentation<Context>
    private let context: Context

    public init(
        presentation: ContextPresentation<Context>,
        context: Context
    ) {
        self.presentation = presentation
        self.context = context
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: symbolName)
                Text(roleTitle)
                    .font(.caption.weight(.semibold))
                Spacer()
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            presentation
                .content(for: context)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var roleTitle: String {
        switch presentation.role {
        case .inspector: "Inspector"
        case .preview: "Preview"
        case .activity: "Activity"
        case .utility: "Utility"
        }
    }

    private var symbolName: String {
        switch presentation.role {
        case .inspector: "slider.horizontal.3"
        case .preview: "eye"
        case .activity: "waveform"
        case .utility: "wrench.and.screwdriver"
        }
    }
}

// MARK: - Workspace Preview Host

/// An isolated development surface for `WorkspacePresentation`.
@MainActor
public struct WorkspacePreviewHost<Context>: View {
    private let presentation: WorkspacePresentation<Context>
    private let context: Context
    private let contextWidth: CGFloat

    public init(
        presentation: WorkspacePresentation<Context>,
        context: Context,
        contextWidth: CGFloat = 280
    ) {
        self.presentation = presentation
        self.context = context
        self.contextWidth = contextWidth
    }

    public var body: some View {
        VStack(spacing: 0) {
            identityRegion

            Divider()

            HStack(spacing: 0) {
                presentation
                    .content(for: context)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let contextualPresentation = presentation.context {
                    Divider()

                    ContextPreviewHost(
                        presentation: contextualPresentation,
                        context: context
                    )
                    .frame(width: contextWidth)
                }
            }

            if let accessory = presentation.workspaceAccessory {
                Divider()

                AccessoryPreviewHost(
                    presentation: accessory,
                    context: context
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var identityRegion: some View {
        if let identity = presentation.identity {
            HStack(spacing: 10) {
                if let systemImage = identity.systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(identity.title)
                        .font(.headline)

                    if let subtitle = identity.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text("Preview Host")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        } else {
            EmptyView()
        }
    }
}

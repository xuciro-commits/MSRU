//
//  WorkspaceIdentity.swift
//  AppFoundationUI
//

// MARK: - Workspace Identity

/// Describes the semantic identity of the active workspace.
///
/// `WorkspaceIdentity` intentionally does not prescribe how identity is rendered.
/// A platform renderer may use it as a window title, navigation title,
/// toolbar identity, or omit it entirely when the workspace itself is self-describing.
public struct WorkspaceIdentity:
    Hashable,
    Sendable {

    public let title: String
    public let subtitle: String?
    public let systemImage: String?

    public init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
    }
}

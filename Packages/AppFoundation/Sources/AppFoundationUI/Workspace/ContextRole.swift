//
//  ContextRole.swift
//  AppFoundationUI
//

// MARK: - Context Role

/// Describes what a contextual presentation means.
///
/// The role is semantic rather than geometric:
/// a context does not imply that it must appear in a right-hand pane.
public enum ContextRole:
    String,
    Hashable,
    Sendable {

    /// Properties and controls for the current selection.
    case inspector

    /// Read-only or primarily informational representation of a selection.
    case preview

    /// Ongoing activity related to the current workspace or application.
    case activity

    /// Supporting tools that do not belong to the primary workspace.
    case utility
}

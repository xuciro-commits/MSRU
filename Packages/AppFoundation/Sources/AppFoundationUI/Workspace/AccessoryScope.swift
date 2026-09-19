//
//  AccessoryScope.swift
//  AppFoundationUI
//

// MARK: - Accessory Scope

/// Defines the lifetime of an accessory presentation.
public enum AccessoryScope:
    String,
    Hashable,
    Sendable {

    /// Persists while the application or scene changes workspaces.
    case application

    /// Belongs to one workspace and disappears when that workspace is replaced.
    case workspace
}

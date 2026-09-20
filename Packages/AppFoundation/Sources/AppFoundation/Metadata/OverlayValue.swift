//
//  OverlayValue.swift
//  AppFoundation
//

import Foundation

/// Describes which layer in the metadata hierarchy produced the active value.
public enum MetadataSource: String, Sendable, Codable, Equatable, Hashable {
    case none
    case raw
    case canonical
    case user
}

/// A generic three-layer cascading metadata property.
///
/// Implements Roon-style overlay resolution:
/// Priority order: `user` (explicit user edits) > `canonical` (graph/identified authority) > `raw` (original file tags).
///
/// Guaranteed invariance: The raw value is never mutated or destroyed by higher layers.
public struct OverlayValue<T: Sendable & Equatable>: Sendable, Equatable, Codable where T: Codable {

    /// The underlying physical/original value read directly from asset or file tags.
    public var raw: T?

    /// The authoritative value computed by identity resolution or external catalog graph.
    public var canonical: T?

    /// The explicit override value provided by the user.
    public var user: T?

    /// Initializes a cascading overlay value with optional layer values.
    public init(
        raw: T? = nil,
        canonical: T? = nil,
        user: T? = nil
    ) {
        self.raw = raw
        self.canonical = canonical
        self.user = user
    }

    /// Convenience initializer setting only the raw layer.
    public static func raw(_ value: T?) -> Self {
        Self(raw: value)
    }

    /// Resolves the effective active value respecting cascading priority:
    /// `user ?? canonical ?? raw`.
    public var resolved: T? {
        if let user {
            return user
        }
        if let canonical {
            return canonical
        }
        return raw
    }

    /// The source tier currently determining `resolved`.
    public var activeSource: MetadataSource {
        if user != nil {
            return .user
        }
        if canonical != nil {
            return .canonical
        }
        if raw != nil {
            return .raw
        }
        return .none
    }

    /// Whether this property is currently overridden by an explicit user edit.
    public var isOverridden: Bool {
        user != nil
    }

    /// Whether this property has an identified canonical value different from its raw value.
    public var isEnriched: Bool {
        guard let canonical else { return false }
        return canonical != raw
    }

    // MARK: - Mutating Operations

    /// Explicitly sets or replaces the user override.
    public mutating func setUserOverride(_ value: T?) {
        self.user = value
    }

    /// Clears the user override, falling back to canonical or raw.
    public mutating func clearUserOverride() {
        self.user = nil
    }

    /// Sets or updates the canonical authoritative value.
    public mutating func setCanonical(_ value: T?) {
        self.canonical = value
    }

    /// Resets this value to the authoritative canonical state by discarding user edits.
    public mutating func resetToCanonical() {
        self.user = nil
    }

    /// Resets this value completely back to the raw source by discarding user and canonical overrides.
    public mutating func resetToRaw() {
        self.user = nil
        self.canonical = nil
    }
}

extension OverlayValue: Hashable where T: Hashable {}

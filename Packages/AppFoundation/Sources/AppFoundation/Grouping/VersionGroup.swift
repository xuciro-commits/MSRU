//
//  VersionGroup.swift
//  AppFoundation
//
//  Created for Identity Resolution Engine Phase 2.
//

import Foundation

/// A generic container representing multiple alternative versions or representations of an entity.
///
/// Manages a designated `primary` item alongside secondary `alternatives`, supporting
/// rule-based or explicit priority selection and automatic fallback upon removal.
public struct VersionGroup<Element: Identifiable & Sendable & Equatable>: Identifiable, Sendable, Equatable, Codable where Element: Codable, Element.ID: Codable & Sendable {

    /// Unique identifier for this version collection.
    public let id: String

    /// Identifier of the designated primary/active version.
    public var primaryID: Element.ID?

    /// All constituent versions belonging to this group.
    public var elements: [Element]

    // MARK: - Initializers

    public init(
        id: String = UUID().uuidString,
        elements: [Element] = [],
        primaryID: Element.ID? = nil
    ) {
        self.id = id
        self.elements = elements
        if let primaryID, elements.contains(where: { $0.id == primaryID }) {
            self.primaryID = primaryID
        } else {
            self.primaryID = elements.first?.id
        }
    }

    /// Convenience initializer with a single primary element.
    public init(primary: Element, id: String = UUID().uuidString) {
        self.id = id
        self.elements = [primary]
        self.primaryID = primary.id
    }

    // MARK: - Accessors

    /// The designated primary element, or the first element if primaryID is unassigned or missing.
    public var primary: Element? {
        guard let primaryID else { return elements.first }
        return elements.first(where: { $0.id == primaryID }) ?? elements.first
    }

    /// All alternative versions excluding the primary.
    public var alternatives: [Element] {
        guard let activePrimary = primary else { return [] }
        return elements.filter { $0.id != activePrimary.id }
    }

    /// Total count of versions in this group.
    public var count: Int {
        elements.count
    }

    /// Whether this group has no versions.
    public var isEmpty: Bool {
        elements.isEmpty
    }

    /// Whether this group contains more than one version.
    public var hasAlternatives: Bool {
        elements.count > 1
    }

    // MARK: - Operations

    /// Explicitly designates a specific element ID as the primary version.
    ///
    /// Returns `true` if the ID exists and was set, `false` otherwise.
    @discardableResult
    public mutating func setPrimary(id: Element.ID) -> Bool {
        guard elements.contains(where: { $0.id == id }) else {
            return false
        }
        self.primaryID = id
        return true
    }

    /// Automatically evaluates and designates the primary version using a priority comparator.
    ///
    /// - Parameter isHigherPriority: A comparator returning `true` when the first argument should precede the second.
    public mutating func selectPrimary(by isHigherPriority: (Element, Element) -> Bool) {
        guard !elements.isEmpty else { return }
        guard var best = elements.first else { return }
        for candidate in elements.dropFirst() {
            if isHigherPriority(candidate, best) {
                best = candidate
            }
        }
        self.primaryID = best.id
    }

    /// Adds a new element or updates an existing one matching `element.id`.
    ///
    /// - Parameters:
    ///   - element: The element to add or update.
    ///   - prioritize: If `true`, this element is immediately designated as the primary version.
    public mutating func addOrUpdate(_ element: Element, prioritize: Bool = false) {
        if let index = elements.firstIndex(where: { $0.id == element.id }) {
            elements[index] = element
        } else {
            elements.append(element)
        }

        if prioritize || primaryID == nil {
            primaryID = element.id
        }
    }

    /// Removes the element with the specified ID.
    ///
    /// If the removed element was the designated primary, updates `primaryID` to the first remaining element.
    ///
    /// - Parameter id: The identifier of the element to remove.
    /// - Returns: The removed element, or `nil` if not found.
    @discardableResult
    public mutating func remove(id: Element.ID) -> Element? {
        guard let index = elements.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        let removed = elements.remove(at: index)
        if primaryID == id {
            primaryID = elements.first?.id
        }
        return removed
    }

    /// Removes all elements and clears the primary designation.
    public mutating func removeAll() {
        elements.removeAll()
        primaryID = nil
    }
}

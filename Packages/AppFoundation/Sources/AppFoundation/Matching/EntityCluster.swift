//
//  EntityCluster.swift
//  AppFoundation
//
//  Created for Identity Resolution Engine Phase 3.
//

import Foundation

/// A generic cluster grouping related entities sharing a common structural or contextual signature.
public struct EntityCluster<Item: Identifiable & Sendable & Equatable>: Identifiable, Sendable, Equatable, Codable where Item: Codable, Item.ID: Codable & Sendable {

    /// Unique identifier for this cluster.
    public let id: String

    /// Optional semantic label (e.g. folder name, album candidate title).
    public var label: String?

    /// Constituent items belonging to this cluster.
    public var items: [Item]

    /// Key-value contextual metadata describing the cluster attributes.
    public var metadata: [String: String]

    public var count: Int {
        items.count
    }

    public var isEmpty: Bool {
        items.isEmpty
    }

    public init(
        id: String = UUID().uuidString,
        label: String? = nil,
        items: [Item] = [],
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.label = label
        self.items = items
        self.metadata = metadata
    }

    /// Appends an item to this cluster.
    public mutating func append(_ item: Item) {
        items.append(item)
    }
}

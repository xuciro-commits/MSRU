//
//  ArrayReordering.swift
//  MSRU
//
//  List reordering with SwiftUI's `move(fromOffsets:toOffset:)` semantics,
//  so stores stay free of UI imports.
//

import Foundation

extension Array {
    mutating func reorder(fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.map { self[$0] }
        var remaining = enumerated()
            .filter { !source.contains($0.offset) }
            .map(\.element)
        remaining.insert(contentsOf: moving, at: destination - source.count(in: 0..<destination))
        self = remaining
    }
}

import Foundation
import Testing
@testable import MusicLibrary

@Suite("Array reordering")
struct ArrayReorderingTests {
    @Test("Matches SwiftUI move(fromOffsets:toOffset:) semantics", arguments: [
        (IndexSet([0]), 3, ["b", "c", "a", "d"]),
        (IndexSet([3]), 0, ["d", "a", "b", "c"]),
        (IndexSet([1, 2]), 4, ["a", "d", "b", "c"]),
        (IndexSet([0, 2]), 2, ["b", "a", "c", "d"]),
        (IndexSet([1]), 1, ["a", "b", "c", "d"]),
        (IndexSet([1]), 2, ["a", "b", "c", "d"])
    ])
    func reorder(source: IndexSet, destination: Int, expected: [String]) {
        var items = ["a", "b", "c", "d"]
        items.reorder(fromOffsets: source, toOffset: destination)
        #expect(items == expected)
    }
}

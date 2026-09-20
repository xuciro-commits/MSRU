//
//  EntityAliasTests.swift
//  AppFoundationTests
//

import Foundation
import Testing
@testable import AppFoundation

struct EntityAliasTests {

    @Test
    func entityAliasCollectionResolvesPreferredLocales() {
        let collection = EntityAliasCollection(
            canonicalName: "周杰倫",
            aliases: [
                EntityAlias(name: "Jay Chou", localeIdentifier: "en", isPrimary: true),
                EntityAlias(name: "周杰伦", localeIdentifier: "zh-Hans"),
                EntityAlias(name: "周杰倫", localeIdentifier: "zh-Hant")
            ]
        )

        // 1. Simplified Chinese preference
        let zhHansName = collection.displayName(preferredLocales: [Locale(identifier: "zh-Hans")])
        #expect(zhHansName == "周杰伦")

        // 2. English preference
        let enName = collection.displayName(preferredLocales: [Locale(identifier: "en")])
        #expect(enName == "Jay Chou")

        // 3. Unknown locale falls back to primary alias or canonical
        let frName = collection.displayName(preferredLocales: [Locale(identifier: "fr")])
        #expect(frName == "Jay Chou", "Should fall back to primary alias")

        // 4. Empty aliases returns canonical
        let emptyCollection = EntityAliasCollection(canonicalName: "Radiohead")
        #expect(emptyCollection.displayName() == "Radiohead")
    }

    @Test
    func entityAliasCollectionCodableRoundtrip() throws {
        let collection = EntityAliasCollection(
            canonicalName: "Taylor Swift",
            aliases: [
                EntityAlias(name: "霉霉", localeIdentifier: "zh-Hans"),
                EntityAlias(name: "Taylor Swift", localeIdentifier: "en", isPrimary: true)
            ]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(collection)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(EntityAliasCollection.self, from: data)

        #expect(decoded.canonicalName == "Taylor Swift")
        #expect(decoded.aliases.count == 2)
        #expect(decoded.displayName(preferredLocales: [Locale(identifier: "zh-Hans")]) == "霉霉")
    }
}

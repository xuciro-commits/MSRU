//
//  SceneID.swift
//  MSRU
//

import Foundation


// MARK: - Scene Identity

/*
 不直接把裸 UUID 暴露为 Scene identity。

 这样未来不会把：

 - Scene UUID
 - Track UUID
 - Provider UUID
 - Library UUID

 在 API 层意外混用。
 */

nonisolated struct SceneID:
    RawRepresentable,
    Codable,
    Hashable,
    Sendable,
    Identifiable,
    CustomStringConvertible {

    let rawValue:
        UUID


    // MARK: - Init

    init(
        rawValue:
            UUID
    ) {

        self.rawValue =
            rawValue
    }


    init() {

        self.rawValue =
            UUID()
    }


    // MARK: - Identifiable

    var id:
        Self {

        self
    }


    // MARK: - Description

    var description:
        String {

        rawValue
            .uuidString
    }
}

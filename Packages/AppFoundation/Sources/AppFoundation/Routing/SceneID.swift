//
//  SceneID.swift
//  AppFoundation
//

import Foundation


// MARK: - Scene ID

/*
 SceneID 表示一个 Application Scene / Window
 的稳定 runtime identity。

 它与：

 - Route
 - Window implementation
 - SwiftUI Scene
 - AppKit NSWindow
 - UIKit UIWindowScene
 - Product Domain

 都无关。
 */

public struct SceneID:
    Hashable,
    Codable,
    Sendable,
    CustomStringConvertible {

    // MARK: - Storage

    public let rawValue:
        UUID


    // MARK: - Init

    public init(
        rawValue:
            UUID = UUID()
    ) {

        self.rawValue =
            rawValue
    }


    // MARK: - Description

    public var description:
        String {

        rawValue
            .uuidString
    }
}

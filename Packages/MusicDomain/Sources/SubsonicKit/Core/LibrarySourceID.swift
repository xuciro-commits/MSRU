//
//  LibrarySourceID.swift
//  SubsonicKit
//
//  Server identity used for credentials, clients and remote references.
//

import Foundation

public struct LibrarySourceID: Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }

    public static let local = LibrarySourceID("local")
}

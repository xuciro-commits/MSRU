//
//  MediaID.swift
//  MediaLibrary
//
//  Composite media identity preventing collisions across different library sources.
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

public struct MediaID: Hashable, Codable, Sendable, CustomStringConvertible {
    public let sourceID: LibrarySourceID
    public let rawValue: String

    public init(sourceID: LibrarySourceID, rawValue: String) {
        self.sourceID = sourceID
        self.rawValue = rawValue
    }

    public var description: String {
        "\(sourceID.rawValue)::\(rawValue)"
    }

    /// Helper constructor for local files.
    public static func local(_ pathOrURL: String) -> MediaID {
        MediaID(sourceID: .local, rawValue: pathOrURL)
    }
}

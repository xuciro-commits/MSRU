//
//  SubsonicCredentials.swift
//  SubsonicKit
//
//  Configuration and credential representation for Subsonic/OpenSubsonic server.
//

import Foundation

public struct SubsonicCredentials: Sendable, Codable, Equatable {
    public let serverID: LibrarySourceID
    public let serverURL: URL
    public let username: String

    public init(
        serverID: LibrarySourceID,
        serverURL: URL,
        username: String
    ) {
        self.serverID = serverID
        self.serverURL = serverURL
        self.username = username
    }
}

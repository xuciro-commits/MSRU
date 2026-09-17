//
//  LocalTrack.swift
//  MSRU
//

import Foundation


struct LocalTrack:
    Identifiable,
    Hashable,
    Sendable {

    let fileURL:
        URL

    let title:
        String

    let artist:
        String

    let album:
        String?

    let duration:
        TimeInterval

    let artworkData:
        Data?


    var id: String {
        fileURL.absoluteString
    }
}

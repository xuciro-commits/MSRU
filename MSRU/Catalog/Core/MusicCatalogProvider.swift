//
//  MusicCatalogProvider.swift
//  MSRU
//

import Foundation


protocol MusicCatalogProvider:
    Sendable {

    var id:
        MusicProviderID { get }


    func homeSections()
        async throws -> [MusicSection]


    func search(
        _ query: String
    ) async throws -> [MusicContent]
}

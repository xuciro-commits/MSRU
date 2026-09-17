//
//  LibraryImportOptions.swift
//  MSRU
//

import Foundation


struct LibraryImportOptions: Equatable {

    var importsArtists = true
    var importsSongs = true
    var importsAlbums = true


    var hasSelection: Bool {
        importsArtists
        || importsSongs
        || importsAlbums
    }
}

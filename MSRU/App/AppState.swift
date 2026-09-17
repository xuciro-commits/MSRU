//
//  AppState.swift
//  MSRU
//

import Foundation
import Observation


@MainActor
@Observable
final class AppState {

    // MARK: - Navigation

    var selectedSection:
        SidebarSection? = .listenNow

    var searchText =
        ""


    // MARK: - Catalog

    var selectedMusicContent:
        MusicContent?

    let musicCatalog =
        MusicCatalogStore()


    // MARK: - Local Library

    var selectedLocalTrack:
        LocalTrack?

    let localLibrary =
        LocalLibraryStore()


    // MARK: - Apple Music

    let musicLibrary =
        AppleMusicLibraryStore()


    // MARK: - Playback

    let playback =
        PlaybackController()


    // MARK: - Presentation

    var isQueuePresented =
        true
}

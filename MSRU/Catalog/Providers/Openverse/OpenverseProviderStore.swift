//
//  OpenverseProviderStore.swift
//  MSRU
//

import AVFoundation
import Foundation
import Observation


@MainActor
@Observable
final class OpenverseProviderStore {

    private let catalog =
        OpenverseCatalogProvider()

    private let player =
        AVPlayer()

    private(set) var results:
        [OpenverseAudio] = []

    private(set) var currentItem:
        OpenverseAudio?

    private(set) var isPlaying =
        false

    private(set) var isLoading =
        false

    private(set) var lastQuery =
        ""

    var errorMessage:
        String?

    init() {
        player.automaticallyWaitsToMinimizeStalling =
            true
    }

    func search(
        _ query:
            String
    ) async {

        let cleaned =
            query
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard !cleaned.isEmpty else {
            results = []
            errorMessage = nil
            lastQuery = ""
            return
        }

        isLoading =
            true

        errorMessage =
            nil

        lastQuery =
            cleaned

        defer {
            isLoading =
                false
        }

        do {
            let items =
                try await catalog
                    .search(
                        cleaned
                    )

            guard !Task.isCancelled,
                  lastQuery == cleaned
            else {
                return
            }

            results =
                items

        } catch is CancellationError {

            return

        } catch {

            guard !Task.isCancelled else {
                return
            }

            errorMessage =
                error.localizedDescription

            results = []
        }
    }

    func togglePlayback(
        _ item:
            OpenverseAudio
    ) {

        if currentItem?.id
            == item.id {

            if isPlaying {
                pause()
            } else {
                resume()
            }

            return
        }

        play(
            item
        )
    }

    func play(
        _ item:
            OpenverseAudio
    ) {

        guard let url =
            item.mediaURL
        else {
            errorMessage =
                "This Openverse result does not contain a valid media URL."

            return
        }

        errorMessage =
            nil

        currentItem =
            item

        let playerItem =
            AVPlayerItem(
                url:
                    url
            )

        player.replaceCurrentItem(
            with:
                playerItem
        )

        player.play()

        isPlaying =
            true
    }

    func pause() {
        player.pause()

        isPlaying =
            false
    }

    func resume() {
        guard player.currentItem != nil else {
            if let currentItem {
                play(
                    currentItem
                )
            }

            return
        }

        player.play()

        isPlaying =
            true
    }

    func stop() {
        player.pause()

        player.replaceCurrentItem(
            with:
                nil
        )

        currentItem =
            nil

        isPlaying =
            false
    }

    func isCurrent(
        _ item:
            OpenverseAudio
    ) -> Bool {

        currentItem?.id
            == item.id
    }
}

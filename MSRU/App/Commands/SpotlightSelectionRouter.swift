import Foundation
import AppFoundation

@MainActor
enum SpotlightSelectionRouter {
    @discardableResult
    static func open(identifier: String, in scene: SceneModel) async -> Bool {
        guard let item = SpotlightMusicID(rawValue: identifier), !scene.isClosed else { return false }
        let library = scene.application.localLibrary
        await library.loadIfNeeded()
        guard !scene.isClosed, library.isLoaded else { return false }

        scene.selectedSourceFilter = nil
        switch item {
        case .track(let id):
            guard let track = try? await library.findTrack(id: id) else { return false }
            scene.send(.navigate(.section(.library)))
            scene.select(localTrack: track)
            scene.application.playback.play(track)
        case .album(let id):
            guard (try? await library.findAlbum(id: id)) != nil else { return false }
            scene.requestedAlbumID = id
            scene.send(.navigate(.section(.albums)))
        case .artist(let id):
            guard (try? await library.findArtist(id: id)) != nil else { return false }
            scene.requestedArtistID = id
            scene.send(.navigate(.section(.artists)))
        }
        return true
    }
}

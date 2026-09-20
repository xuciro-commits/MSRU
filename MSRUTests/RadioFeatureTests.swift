//
//  RadioFeatureTests.swift
//  MSRUTests
//

import Foundation
import Testing
import AppFoundation
import AppFoundationUI

@testable import MSRU

@MainActor
struct RadioFeatureTests {

    // MARK: - Domain & Store Tests

    @Test
    func radioStoreProvidesDefaultStationsAndFiltersByGenre() {
        let store = RadioStore()

        #expect(!store.stations.isEmpty)
        #expect(!store.featuredStations.isEmpty)

        let allStations = store.filteredStations(genre: .all)
        #expect(allStations.count == store.stations.count)

        let indieStations = store.filteredStations(genre: .indie)
        #expect(indieStations.allSatisfy { $0.genre == .indie })
        #expect(!indieStations.isEmpty)

        let electronicStations = store.filteredStations(genre: .electronic)
        #expect(electronicStations.allSatisfy { $0.genre == .electronic })
    }

    @Test
    func radioStoreFiltersBySearchQuery() {
        let store = RadioStore()

        let searchKEXP = store.filteredStations(genre: .all, query: "KEXP")
        #expect(searchKEXP.count == 1)
        #expect(searchKEXP.first?.name.contains("KEXP") == true)

        let searchCountry = store.filteredStations(genre: .all, query: "United Kingdom")
        #expect(!searchCountry.isEmpty)
        #expect(searchCountry.allSatisfy { $0.country == "United Kingdom" })

        let emptyResult = store.filteredStations(genre: .all, query: "NonExistentStationXYZ123")
        #expect(emptyResult.isEmpty)
    }

    @Test
    func radioStoreAddsAndRemovesCustomStation() {
        let store = RadioStore(stations: [], persistenceURL: nil)
        #expect(store.allStations.isEmpty)

        let customStation = RadioStation(
            id: "custom-test-1",
            name: "Test Station",
            description: "Testing custom station insertion",
            genre: .ambient,
            streamURL: URL(string: "https://example.com/stream.aac")!,
            isCustom: true
        )

        store.addCustomStation(customStation)
        #expect(store.allStations.count == 1)
        #expect(store.allStations.first?.id == "custom-test-1")
        #expect(store.isCustomStation(id: "custom-test-1"))

        // Duplicate add is idempotent
        store.addCustomStation(customStation)
        #expect(store.allStations.count == 1)

        store.deleteCustomStation(id: "custom-test-1")
        #expect(store.allStations.isEmpty)
        #expect(!store.isCustomStation(id: "custom-test-1"))
    }

    @Test
    func radioStoreTogglesFavoriteAndMaintainsFavoritesList() {
        let store = RadioStore(persistenceURL: nil)
        let station = store.stations[0]

        #expect(!store.isFavorite(id: station.id))
        #expect(store.favoriteStations.isEmpty)

        store.toggleFavorite(id: station.id)
        #expect(store.isFavorite(id: station.id))
        #expect(store.favoriteStations.map(\.id) == [station.id])

        store.toggleFavorite(id: station.id)
        #expect(!store.isFavorite(id: station.id))
        #expect(store.favoriteStations.isEmpty)
    }

    @Test
    func radioStoreRecordsPlayedStationHistory() {
        let store = RadioStore(persistenceURL: nil)
        let first = store.stations[0]
        let second = store.stations[1]

        #expect(store.recentStations.isEmpty)

        store.recordPlayed(station: first)
        #expect(store.recentStations.map(\.id) == [first.id])

        store.recordPlayed(station: second)
        #expect(store.recentStations.map(\.id) == [second.id, first.id])

        // Re-playing first moves it to the top
        store.recordPlayed(station: first)
        #expect(store.recentStations.map(\.id) == [first.id, second.id])
    }

    @Test
    func radioPersistenceSurvivesStoreRecreation() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let fileURL = root.appendingPathComponent("radio_test.json")
        let firstStore = RadioStore(persistenceURL: fileURL)

        let custom = RadioStation(
            id: "custom-persist-1",
            name: "Persist Station",
            description: "Persisted station",
            genre: .electronic,
            streamURL: URL(string: "https://example.com/persist.mp3")!,
            isCustom: true
        )
        firstStore.addCustomStation(custom)
        firstStore.toggleFavorite(id: custom.id)
        firstStore.recordPlayed(station: custom)

        #expect(firstStore.isFavorite(id: custom.id))
        #expect(firstStore.isCustomStation(id: custom.id))

        // Recreate store pointing to the same file
        let reloadedStore = RadioStore(persistenceURL: fileURL)
        #expect(reloadedStore.isCustomStation(id: custom.id))
        #expect(reloadedStore.isFavorite(id: custom.id))
        #expect(reloadedStore.favoriteStations.map(\.id).contains(custom.id))
        #expect(reloadedStore.recentStations.map(\.id).contains(custom.id))
    }

    // MARK: - Playback Provider & Item Tests

    @Test
    func radioPlaybackProviderResolvesValidStreamURL() async throws {
        let provider = RadioPlaybackProvider()
        #expect(provider.id == .radio)

        let validURL = URL(string: "https://stream.example.com/radio.aac")!
        let request = PlaybackRequest(
            itemID: "radio:test-1",
            source: .radio,
            remoteURL: validURL,
            providerHint: .radio
        )

        #expect(provider.canResolve(request))

        let resource = try await provider.resolve(request)
        #expect(resource.providerID == .radio)
        if case .avPlayerURL(let url) = resource.transport {
            #expect(url == validURL)
        } else {
            Issue.record("Expected avPlayerURL transport")
        }
    }

    @Test
    func radioPlaybackProviderRejectsInvalidScheme() async {
        let provider = RadioPlaybackProvider()
        let fileURL = URL(string: "ftp://stream.example.com/live")!
        let request = PlaybackRequest(
            itemID: "radio:bad-scheme",
            source: .radio,
            remoteURL: fileURL
        )

        #expect(provider.canResolve(request))

        do {
            _ = try await provider.resolve(request)
            Issue.record("Expected error for non-http scheme")
        } catch {
            #expect(error is LocalizedError)
        }
    }

    @Test
    func playbackItemFormatsRadioStationPayloadCorrectly() {
        let station = RadioStation(
            id: "kexp-test",
            name: "KEXP 90.3",
            description: "Music that matters",
            genre: .indie,
            streamURL: URL(string: "https://kexp.streamguys1.com/kexp128.aac")!,
            country: "United States",
            language: "English",
            codec: "AAC",
            bitrateKbps: 128
        )

        let item = PlaybackItem(radio: station)
        #expect(item.id == "radio:kexp-test")
        #expect(item.source == .radio)
        #expect(item.title == "KEXP 90.3")
        #expect(item.subtitle.contains("Indie & Alternative"))
        #expect(item.subtitle.contains("United States"))
        #expect(item.providerLabel == "LIVE RADIO")
        #expect(item.duration == nil) // Continuous live stream has no finite duration
        #expect(item.radioStation?.id == station.id)

        let request = item.playbackRequest
        #expect(request.source == .radio)
        #expect(request.remoteURL == station.streamURL)
        #expect(request.providerHint == .radio)
    }

    // MARK: - PlaybackController Radio Integration

    @Test
    func playbackControllerPlaysAndTracksRadioStation() {
        let controller = PlaybackController()
        let station = RadioStation.defaultStations[0]

        #expect(controller.radioCurrentStation == nil)
        #expect(controller.state(for: station) == .idle)

        controller.play(radio: station)

        #expect(controller.radioCurrentStation?.id == station.id)
        #expect(controller.currentItem?.source == .radio)
        #expect(controller.unifiedTitle == station.name)
        #expect(controller.unifiedProviderLabel == "LIVE RADIO")
    }

    // MARK: - SceneModel & FeatureHost Integration

    @Test
    func sceneModelSelectRadioStationUpdatesSelectionAndInspectContext() {
        let application = MSRUPreviewData.makeApplication()
        let scene = SceneModel(application: application, isQueuePresented: false)

        #expect(scene.selectedRadioStation == nil)
        #expect(!scene.isQueuePresented)

        let station = RadioStation.defaultStations[0]
        scene.select(radioStation: station)

        #expect(scene.selectedRadioStation?.id == station.id)
        #expect(scene.selectedLocalTrack == nil)
        #expect(scene.selectedMusicContent == nil)
        #expect(scene.selectedLibraryTrack == nil)
        #expect(scene.activeContextPane == .inspector)
        #expect(scene.isQueuePresented)

        // Deselection
        scene.select(radioStation: nil)
        #expect(scene.selectedRadioStation == nil)
    }

    @Test
    func radioFeatureStateRespondsToGenreAndQueryChanges() {
        let store = RadioStore()
        var dependencies = DependencyValues.live
        dependencies.radioStore = store
        let playback = PlaybackController()
        dependencies.playback = playback

        let host = withDependencies(dependencies) {
            FeatureHost<RadioFeature>(
                service: RadioFeature.Service()
            )
        }

        #expect(host.state.stations.isEmpty)

        host.send(.appeared)
        #expect(!host.state.stations.isEmpty)
        #expect(host.state.selectedGenre == .all)

        // Select genre
        host.send(.genreSelected(.electronic))
        #expect(host.state.selectedGenre == .electronic)
        #expect(host.state.stations.allSatisfy { $0.genre == .electronic })

        // Change query
        host.send(.searchQueryChanged("Groove Salad"))
        #expect(host.state.stations.count == 1)
        #expect(host.state.stations.first?.name.contains("Groove Salad") == true)
    }

    @Test
    func sceneModelStopsRadioFeatureOnClose() {
        let application = MSRUPreviewData.makeApplication()
        let scene = SceneModel(application: application)

        #expect(!scene.isClosed)
        scene.close()
        #expect(scene.isClosed)
    }

    @Test
    func applicationDefinitionRegistersRadioFeature() throws {
        let definition = MSRUApplication.definition
        let validation = definition.validate()
        #expect(validation.isValid, "\(validation.debugDescription)")

        let scene = MSRUPreviewData.makeScene(section: .radio)
        defer { scene.close() }
        let session = MSRUApplicationShellSession(scene: scene)
        let resolved = session.resolve()

        #expect(resolved.workspace?.identity?.title == "电台")
        let searchItem = try #require(resolved.toolbar.item(id: "radio.search"))
        if case .search(let search) = searchItem {
            #expect(search.prompt == "搜索电台、类型或国家")
        } else {
            Issue.record("Expected search item in radio toolbar")
        }
    }

    @Test
    func radioFeatureHandlesFavoriteAndCustomStationActions() {
        let store = RadioStore(persistenceURL: nil)
        var dependencies = DependencyValues.test
        dependencies.radioStore = store
        let playback = PlaybackController()
        dependencies.playback = playback

        let host = withDependencies(dependencies) {
            FeatureHost<RadioFeature>(service: RadioFeature.Service())
        }

        host.send(.appeared)
        let station = host.state.stations[0]

        #expect(!host.isFavorite(station))
        host.send(.toggleFavoriteRequested(station))
        #expect(host.isFavorite(station))
        #expect(host.state.favoriteStations.map(\.id).contains(station.id))

        // Add custom station via feature
        let custom = RadioStation(
            id: "custom-feat-1",
            name: "Feature Station",
            description: "Desc",
            genre: .pop,
            streamURL: URL(string: "https://example.com/feat.aac")!,
            isCustom: true
        )
        host.send(.addCustomStationRequested(custom))
        #expect(host.state.stations.map(\.id).contains(custom.id))

        // Delete custom station
        host.send(.deleteCustomStationRequested(custom.id))
        #expect(!host.state.stations.map(\.id).contains(custom.id))
    }
}

import Foundation
import MusicKit
import Testing
@testable import MSRU

@MainActor
private final class MemoryLocalRepository: LocalLibraryRepository {
    var loads = 0
    var shouldFail = true
    var importedURLs: [URL] = []
    let track = MSRUPreviewData.localTracks[0]

    func loadTracks() async throws -> [LocalTrack] {
        loads += 1
        if shouldFail { throw CocoaError(.fileReadNoPermission) }
        return [track]
    }

    func importTrack(from url: URL) async throws -> LocalTrack? {
        importedURLs.append(url)
        if shouldFail { throw CocoaError(.fileWriteNoPermission) }
        return track
    }
}

@MainActor
struct LibraryDependencyTests {
    @Test
    func failedLocalLoadCanRetryAndSuccessfulLoadIsCached() async {
        let repository = MemoryLocalRepository()
        let store = LocalLibraryStore(repository: repository)
        await store.loadIfNeeded()
        #expect(store.errorMessage != nil)
        repository.shouldFail = false
        await store.loadIfNeeded()
        await store.loadIfNeeded()
        #expect(repository.loads == 2)
        #expect(store.tracks == [repository.track])
        #expect(store.errorMessage == nil)
    }

    @Test
    func localImportFailureResetsBusyStateAndRetryAvoidsDuplicates() async {
        let repository = MemoryLocalRepository()
        let store = LocalLibraryStore(repository: repository)
        let url = URL(fileURLWithPath: "/fixture/song.m4a")
        await store.importFiles([url])
        #expect(!store.isImporting)
        #expect(store.errorMessage != nil)
        repository.shouldFail = false
        await store.importFiles([url, url])
        #expect(store.tracks == [repository.track])
        #expect(store.errorMessage == nil)
        #expect(!store.isImporting)
        #expect(repository.importedURLs == [url, url, url])
    }

    @Test
    func previewApplicationUsesIsolatedServices() async {
        let application = MSRUPreviewData.makeApplication()
        await application.localLibrary.loadIfNeeded()
        #expect(application.localLibrary.tracks == MSRUPreviewData.localTracks)
        await application.localLibrary.importFiles([URL(fileURLWithPath: "/not-a-real-file.mp3")])
        #expect(application.localLibrary.errorMessage != nil)
        #expect(application.localLibrary.tracks == MSRUPreviewData.localTracks)
        #expect(application.musicLibrary.authorizationStatus == .notDetermined)
        let imported = await application.musicLibrary.importLibrary(options: LibraryImportOptions())
        #expect(!imported)
        #expect(application.musicLibrary.authorizationStatus == .denied)
        let providerID = application.providerManager.addRemoteProvider(
            name: "Preview", endpoint: "https://preview.invalid", capabilities: [.catalog])
        await application.providerManager.testConnection(id: providerID)
        #expect(application.providerManager.provider(id: providerID)?.health == .available)
        #expect(!MSRUPreviewData.makeProviderStore().providers.contains { $0.id == providerID })
    }
}

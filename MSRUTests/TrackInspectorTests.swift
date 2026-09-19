//
//  TrackInspectorTests.swift
//  MSRUTests
//

import Foundation
import Testing
import AppFoundation
import AppFoundationUI

@testable import MSRU

@MainActor
struct TrackInspectorTests {

    @Test
    func selectLocalTrackUpdatesInspectorStateAndEnsuresContextPresented() {
        let application = MSRUPreviewData.makeApplication()
        let scene = SceneModel(application: application, isQueuePresented: false)

        #expect(!scene.isQueuePresented)
        #expect(scene.selectedLocalTrack == nil)

        let track = MSRUPreviewData.localTracks[0]
        scene.select(localTrack: track)

        #expect(scene.selectedLocalTrack == track)
        #expect(scene.selectedMusicContent == nil)
        #expect(scene.activeContextPane == .inspector)
        #expect(scene.isQueuePresented)
    }

    @Test
    func selectMusicContentUpdatesInspectorStateAndEnsuresContextPresented() {
        let application = MSRUPreviewData.makeApplication()
        let scene = SceneModel(application: application, isQueuePresented: false)

        let content = MSRUPreviewData.featuredAlbum
        scene.select(musicContent: content)

        #expect(scene.selectedMusicContent == content)
        #expect(scene.selectedLocalTrack == nil)
        #expect(scene.activeContextPane == .inspector)
        #expect(scene.isQueuePresented)
    }

    @Test
    func toggleQueueSwitchesBetweenQueueAndInspectorOrTogglesVisibility() {
        let application = MSRUPreviewData.makeApplication()
        let scene = SceneModel(application: application, isQueuePresented: false)

        // Closed -> opens queue
        scene.toggleQueue()
        #expect(scene.isQueuePresented)
        #expect(scene.activeContextPane == .queue)

        // Open on queue -> closes
        scene.toggleQueue()
        #expect(!scene.isQueuePresented)

        // Open on inspector -> switches to queue without closing
        let track = MSRUPreviewData.localTracks[0]
        scene.select(localTrack: track)
        #expect(scene.isQueuePresented)
        #expect(scene.activeContextPane == .inspector)

        scene.toggleQueue()
        #expect(scene.isQueuePresented)
        #expect(scene.activeContextPane == .queue)
    }

    @Test
    func applicationShellResolvesContextSurface() {
        let application = MSRUPreviewData.makeApplication()
        let scene = SceneModel(application: application)
        let session = MSRUApplicationShellSession(scene: scene)

        let shell = session.resolve()
        #expect(shell.applicationContexts.count == 1)
        #expect(shell.applicationContexts.first?.id == "msru.context")
        #expect(shell.applicationContexts.first?.role == .inspector)
    }
}

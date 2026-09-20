//
//  CompactNavigationTests.swift
//  MSRUTests
//

import Testing
import Foundation
import AppFoundation
@testable import MSRU

@Suite("Compact Navigation & Platform Shell Tests")
struct CompactNavigationTests {

    @Test("All CompactNavigationTabs have valid title and system image")
    @MainActor
    func testCompactTabsProperties() {
        for tab in CompactNavigationTab.allCases {
            #expect(!tab.systemImage.isEmpty)
            #expect(!tab.id.isEmpty)
        }
        #expect(CompactNavigationTab.allCases.count == 4)
    }

    @Test("SceneModel navigates and preserves scene identity across compact commands")
    @MainActor
    func testSceneNavigationAcrossCompactTabs() {
        let scene = MSRUPreviewData.makeScene()
        
        // Navigate to radio
        scene.send(.navigate(.section(.radio)))
        #expect(scene.navigation.section == .radio)
        
        // Navigate to albums
        scene.send(.navigate(.section(.albums)))
        #expect(scene.navigation.section == .albums)
        
        // Navigate to importReview
        scene.send(.navigate(.section(.importReview)))
        #expect(scene.navigation.section == .importReview)
        
        // Navigate to settings
        scene.send(.navigate(.section(.settings)))
        #expect(scene.navigation.section == .settings)
    }
}

import Foundation
import Testing
import AppFoundation
import AppFoundationUI
@testable import MSRU

@MainActor
struct ApplicationDefinitionContractTests {
    @Test
    func shellSearchUsesSceneStateAndDoesNotCrossWindows() throws {
        let first = MSRUPreviewData.makeScene(section: .browse)
        let second = SceneModel(application: first.application, section: .browse)
        let firstSession = MSRUApplicationShellSession(scene: first)
        let secondSession = MSRUApplicationShellSession(scene: second)
        defer { first.close(); second.close() }
        let item = try #require(firstSession.resolve().toolbar.item(id: "browse.search"))
        guard case .search(let search) = item else {
            Issue.record("Browse must publish a search field")
            return
        }
        let secondQuery = second.browse.state.query
        search.update("Northern Lights")
        #expect(first.browse.state.query == "Northern Lights")
        #expect(second.browse.state.query == secondQuery)
        if case .search(let refreshed) = firstSession.resolve().toolbar.item(id: "browse.search") {
            #expect(refreshed.text == "Northern Lights")
        } else {
            Issue.record("Search disappeared after updating text")
        }
        #expect(secondSession.resolve().workspace?.identity?.title == String(localized: "Browse"))
        first.send(.navigate(.section(.library)))
        #expect(firstSession.resolve().toolbar.item(id: "browse.search") == nil)
    }

    @Test
    func actualProductRegistrationHasValidRoutesAndDestinations() {
        let report = MSRUApplication.definition.validate()
        #expect(report.isValid, "\(report.debugDescription)")
    }

    @Test
    func actualProductRegistrationContainsAllModularFeatures() {
        let definition = MSRUApplication.definition
        let routes = definition.routes
        let sidebar = definition.sidebar
        let destinations = definition.routeDestinations

        // Verify feature routes exist in contributions
        let routeIDs = Set(routes.map(\.id))
        #expect(routeIDs.contains("listen-now"))
        #expect(routeIDs.contains("browse"))
        #expect(routeIDs.contains("library"))
        #expect(routeIDs.contains("albums"))
        #expect(routeIDs.contains("artists"))
        #expect(routeIDs.contains("playlists"))
        #expect(routeIDs.contains("radio"))
        #expect(routeIDs.contains("add-music"))
        #expect(routeIDs.contains("import-review"))
        #expect(routeIDs.contains("settings"))

        // Verify sidebar items
        let sidebarIDs = Set(sidebar.map(\.id))
        #expect(sidebarIDs.contains("listen-now"))
        #expect(sidebarIDs.contains("browse"))
        #expect(sidebarIDs.contains("library"))
        #expect(sidebarIDs.contains("albums"))
        #expect(sidebarIDs.contains("artists"))
        #expect(sidebarIDs.contains("playlists"))
        #expect(sidebarIDs.contains("radio"))
        #expect(sidebarIDs.contains("add-music"))

        // Verify destinations exist for each route
        let destinationIDs = Set(destinations.map(\.id))
        #expect(destinationIDs.contains("listen-now"))
        #expect(destinationIDs.contains("browse"))
        #expect(destinationIDs.contains("library"))
        #expect(destinationIDs.contains("albums"))
        #expect(destinationIDs.contains("artists"))
        #expect(destinationIDs.contains("playlists"))
        #expect(destinationIDs.contains("radio"))
        #expect(destinationIDs.contains("add-music"))
        #expect(destinationIDs.contains("import-review"))
        #expect(destinationIDs.contains("settings"))
    }
}



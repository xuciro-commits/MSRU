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
        #expect(secondSession.resolve().workspace?.identity?.title == "Browse")
        first.send(.navigate(.section(.library)))
        #expect(firstSession.resolve().toolbar.item(id: "browse.search") == nil)
    }

    @Test
    func actualProductRegistrationHasValidRoutesAndDestinations() {
        let report = MSRUApplication.definition.validate()
        #expect(report.isValid, "\(report.debugDescription)")
    }
}

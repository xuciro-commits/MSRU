//
//  ApplicationShellResolverTests.swift
//  AppFoundationUITests
//

import SwiftUI
import Testing
@testable import AppFoundationUI

private enum ResolverTestRoute {
    case home
    case missing
}

private struct ResolverWorkspaceContext {
    let title: String
}

private struct ResolverShellContext {
    let value: String
}

struct ApplicationShellResolverTests {

    @Test
    @MainActor
    func resolvesApplicationAndWorkspaceSurfacesTogether() {
        let shell = makeApplicationShell()

        let resolver = ApplicationShellResolver<
            ResolverTestRoute,
            ResolverWorkspaceContext,
            ResolverShellContext
        >(
            shell: shell,
            workspace: { route, _ in
                guard route == .home else { return nil }
                return makeWorkspace()
            }
        )

        let resolved = resolver.resolve(
            route: .home,
            workspaceContext: .init(title: "Workspace"),
            shellContext: .init(value: "Application")
        )

        #expect(resolved.workspace != nil)
        #expect(resolved.applicationContexts(role: .activity).map(\.id) == ["application.activity"])
        #expect(resolved.applicationAccessories.map(\.id) == ["application.accessory"])
        #expect(resolved.workspace?.context?.id == "workspace.preview")
        #expect(resolved.workspace?.workspaceAccessory?.id == "workspace.accessory")
    }

    @Test
    @MainActor
    func mergesApplicationAndWorkspaceToolbars() {
        let resolver = ApplicationShellResolver<
            ResolverTestRoute,
            ResolverWorkspaceContext,
            ResolverShellContext
        >(
            shell: makeApplicationShell(),
            workspace: { route, _ in
                route == .home ? makeWorkspace() : nil
            }
        )

        let resolved = resolver.resolve(
            route: .home,
            workspaceContext: .init(title: "Workspace"),
            shellContext: .init(value: "Application")
        )

        #expect(resolved.toolbar.items.map(\.id) == ["application.action", "workspace.action"])
    }

    @Test
    @MainActor
    func applicationShellSurvivesMissingWorkspace() {
        let resolver = ApplicationShellResolver<
            ResolverTestRoute,
            ResolverWorkspaceContext,
            ResolverShellContext
        >(
            shell: makeApplicationShell(),
            workspace: { _, _ in nil }
        )

        let resolved = resolver.resolve(
            route: .missing,
            workspaceContext: .init(title: "Unused"),
            shellContext: .init(value: "Application")
        )

        #expect(resolved.workspace == nil)
        #expect(resolved.applicationContexts.count == 1)
        #expect(resolved.applicationAccessories.count == 1)
        #expect(resolved.toolbar.items.map(\.id) == ["application.action"])
    }

    @Test
    @MainActor
    func resolvesContextByIdentifier() {
        let activity = ContextPresentation<ResolverShellContext>(id: "activity", role: .activity) { context in
            Text(context.value)
        }
        let presentation = ApplicationShellPresentation(contexts: [activity])
        #expect(presentation.context(id: "activity")?.role == .activity)
    }

    @Test
    @MainActor
    func resolvesApplicationAccessoryByIdentifier() {
        let accessory = AccessoryPresentation<ResolverShellContext>(id: "player", scope: .application) { context in
            Text(context.value)
        }
        let presentation = ApplicationShellPresentation(accessories: [accessory])
        #expect(presentation.accessory(id: "player")?.scope == .application)
    }

    @Test
    @MainActor
    func filtersContextsBySemanticRole() {
        let inspector = ContextPresentation<ResolverShellContext>(id: "inspector", role: .inspector) { _ in
            Text("Inspector")
        }
        let activity = ContextPresentation<ResolverShellContext>(id: "activity", role: .activity) { _ in
            Text("Activity")
        }
        let presentation = ApplicationShellPresentation(contexts: [inspector, activity])
        let activities = presentation.contexts(role: .activity)
        #expect(activities.count == 1)
        #expect(activities.first?.id == "activity")
    }

    // MARK: - Fixtures

    @MainActor
    private func makeApplicationShell() -> ApplicationShellPresentation<ResolverShellContext> {
        ApplicationShellPresentation(
            contexts: [
                ContextPresentation(id: "application.activity", role: .activity) { context in
                    Text(context.value)
                }
            ],
            accessories: [
                AccessoryPresentation(id: "application.accessory", scope: .application) { context in
                    Text(context.value)
                }
            ],
            toolbar: ToolbarPresentation(
                items: [
                    .action(
                        ToolbarActionPresentation(
                            id: "application.action",
                            title: "Application Action",
                            systemImage: "gear",
                            perform: { _ in }
                        )
                    )
                ]
            )
        )
    }

    @MainActor
    private func makeWorkspace() -> WorkspacePresentation<ResolverWorkspaceContext> {
        WorkspacePresentation(
            identity: WorkspaceIdentity(title: "Workspace"),
            toolbar: ToolbarPresentation(
                items: [
                    .action(
                        ToolbarActionPresentation(
                            id: "workspace.action",
                            title: "Workspace Action",
                            systemImage: "hammer",
                            perform: { _ in }
                        )
                    )
                ]
            ),
            context: ContextPresentation(id: "workspace.preview", role: .preview) { context in
                Text(context.title)
            },
            workspaceAccessory: AccessoryPresentation(id: "workspace.accessory", scope: .workspace) { context in
                Text(context.title)
            }
        ) { context in
            Text(context.title)
        }
    }
}

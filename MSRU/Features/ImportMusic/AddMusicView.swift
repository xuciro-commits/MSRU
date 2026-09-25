//
//  AddMusicView.swift
//  MSRU
//

import SwiftUI
import UniformTypeIdentifiers
import Observation
import AppFoundation
import AppFoundationUI
import MusicLibrary
import MusicPlayback

/// Entry point for bringing music in. One-off file imports and Apple Music
/// imports happen here; ongoing sources (watched folders, servers) are owned
/// by the Sources page, so those cards navigate there.
struct AddMusicView: View {
    @Bindable var localStore: LocalLibraryStore
    @Bindable var appleMusicStore: AppleMusicLibraryStore
    var playlistStore: PlaylistStore? = nil
    let onOpenLibrary: () -> Void
    let onOpenSources: () -> Void

    @State private var route: Route = .root
    @State private var isFileImporterPresented = false
    @State private var importErrorMessage: String?

    var body: some View {
        Group {
            switch route {
            case .root: rootContent
            case .appleMusic: appleMusicContent
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: LocalAudioFormatSupport.importContentTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                Task {
                    await localStore.importFiles(urls)
                    onOpenLibrary()
                }
            case .failure(let error):
                if (error as? CocoaError)?.code != .userCancelled {
                    importErrorMessage = error.localizedDescription
                }
            }
        }
        .alert(
            "Couldn't Import Files",
            isPresented: Binding(
                get: { importErrorMessage != nil },
                set: { if !$0 { importErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage ?? "")
        }
    }

    private var rootContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 280, maximum: 420), spacing: 18)],
                    spacing: 18
                ) {
                    actionCard(
                        title: "Files",
                        description: "Import audio files into MSRU Library.",
                        systemImage: "doc.badge.plus"
                    ) {
                        isFileImporterPresented = true
                    }

                    actionCard(
                        title: "Folders",
                        description: "Watch folders so new music is added automatically.",
                        systemImage: "folder.badge.plus",
                        action: onOpenSources
                    )

                    actionCard(
                        title: "NAS or Subsonic Server",
                        description: "Stream from a NAS, Navidrome, or any Subsonic-compatible server.",
                        systemImage: "server.rack",
                        action: onOpenSources
                    )

                    actionCard(
                        title: "Apple Music",
                        description: "Connect or import albums, artists, and songs via Apple Music.",
                        systemImage: "apple.logo"
                    ) {
                        route = .appleMusic
                    }
                }
            }
            .padding(28)
        }
        .hideScrollIndicatorsCompletely()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Add Music")
                .font(.largeTitle.bold())
            Text("Import local media, or import music from connected services.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var appleMusicContent: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    route = .root
                } label: {
                    Label("Add Music", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.top, 18)

            AppleMusicImportView(
                store: appleMusicStore,
                localStore: localStore,
                playlistStore: playlistStore,
                onImportCompleted: onOpenLibrary
            )
        }
    }

    private func actionCard(
        title: LocalizedStringKey,
        description: LocalizedStringKey,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: systemImage)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.title3.bold())
                    Text(description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                HStack {
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private extension AddMusicView {
    enum Route {
        case root
        case appleMusic
    }
}

// MARK: - Feature

enum AddMusicFeature: ApplicationFeaturePresentation {
    typealias Route = SceneRoute
    typealias PresentationContext = SceneModel

    nonisolated static var contributions: FeatureContribution<Route> {
        FeatureContribution(
            sidebar: [
                SidebarContribution(
                    id: "add-music",
                    group: "Source & Import",
                    title: "Add Music",
                    systemImage: "plus.circle",
                    route: .section(.addMusic),
                    order: 210
                ),
                SidebarContribution(
                    id: "metadata-center",
                    group: "Source & Import",
                    title: "Metadata Center",
                    systemImage: "sparkles.rectangle.stack",
                    route: .section(.importReview),
                    order: 220
                )
            ],
            routes: [
                RouteContribution(
                    id: "add-music",
                    route: .section(.addMusic)
                ),
                RouteContribution(
                    id: "import-review",
                    route: .section(.importReview)
                )
            ]
        )
    }

    @MainActor
    static var routeDestinations: [RouteDestination<Route, PresentationContext>] {
        [
            RouteDestination(
                id: "add-music",
                route: .section(.addMusic)
            ) { scene in
                WorkspacePresentation(
                    identity: WorkspaceIdentity(
                        title: "Add Music",
                        systemImage: "plus.circle"
                    )
                ) { _ in
                    AddMusicView(
                        localStore: scene.application.localLibrary,
                        appleMusicStore: scene.application.musicLibrary,
                        playlistStore: scene.application.playlistStore,
                        onOpenLibrary: {
                            scene.send(.navigate(.section(.library)))
                        },
                        onOpenSources: {
                            scene.send(.navigate(.section(.sources)))
                        }
                    )
                }
            },
            RouteDestination(
                id: "import-review",
                route: .section(.importReview)
            ) { scene in
                WorkspacePresentation(
                    identity: WorkspaceIdentity(
                        title: "Metadata Center",
                        systemImage: "sparkles.rectangle.stack"
                    )
                ) { _ in
                    MetadataManagerWorkspaceView(
                        localStore: scene.application.localLibrary,
                        watchedFolders: scene.application.watchedFolders,
                        onOpenLibrary: {
                            scene.send(.navigate(.section(.library)))
                        }
                    )
                }
            }
        ]
    }
}

// MARK: - Preview

#Preview {
    AddMusicView(
        localStore: MSRUPreviewData.makeLocalLibraryStore(),
        appleMusicStore: MSRUPreviewData.makeAppleMusicStore(),
        onOpenLibrary: {},
        onOpenSources: {}
    )
    .frame(width: 1000, height: 700)
}


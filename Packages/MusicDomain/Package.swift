// swift-tools-version: 6.2

import PackageDescription

// Music domain packages for MSRU. Nothing here may be imported by
// AppFoundation or by platform-level code.
//   MusicDomain   — UI-free music types and toolkits (Foundation only)
//   MusicLibrary  — library, persistence (GRDB), identity, import, catalog,
//                   providers, queries, radio
//   MusicPlayback — playback engine, CoreAudio output, DSP, codecs, queue
//   SubsonicKit   — Subsonic/OpenSubsonic client, credentials, capability probe
// Dependencies point downward: MusicPlayback → MusicLibrary → MusicDomain;
// MusicLibrary and MusicPlayback also use SubsonicKit, which depends on nothing.
// Moved app-target code keeps the app's concurrency semantics
// (default MainActor isolation, approachable concurrency).
let appTargetSettings: [SwiftSetting] = [
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("MemberImportVisibility")
]

let package = Package(
    name: "MusicDomain",

    platforms: [
        .macOS("27.0"),
        .iOS("27.0"),
        .tvOS("27.0"),
        .watchOS("27.0"),
        .visionOS("27.0")
    ],

    products: [
        .library(name: "MusicDomain", targets: ["MusicDomain"]),
        .library(name: "MusicLibrary", targets: ["MusicLibrary"]),
        .library(name: "MusicPlayback", targets: ["MusicPlayback"]),
        .library(name: "SubsonicKit", targets: ["SubsonicKit"])
    ],

    dependencies: [
        .package(path: "../AppFoundation"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.11.0"),
        .package(path: "../ChromaSwift"),
        .package(path: "../MSRUCodecFFmpeg")
    ],

    targets: [
        .target(name: "MusicDomain"),
        .target(name: "SubsonicKit"),
        .target(
            name: "MusicLibrary",
            dependencies: [
                "MusicDomain",
                .product(name: "AppFoundation", package: "AppFoundation"),
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "ChromaSwift", package: "ChromaSwift"),
                "SubsonicKit"
            ],
            swiftSettings: appTargetSettings
        ),
        .target(
            name: "MusicPlayback",
            dependencies: [
                "MusicDomain",
                "MusicLibrary",
                .product(name: "AppFoundation", package: "AppFoundation"),
                .product(name: "GRDB", package: "GRDB.swift"),
                "SubsonicKit",
                .product(name: "MSRUCodecFFmpeg", package: "MSRUCodecFFmpeg")
            ],
            swiftSettings: appTargetSettings
        ),
        .testTarget(
            name: "MusicDomainTests",
            dependencies: ["MusicDomain"]
        ),
        .testTarget(
            name: "SubsonicKitTests",
            dependencies: ["SubsonicKit"]
        ),
        .testTarget(
            name: "MusicLibraryTests",
            dependencies: ["MusicLibrary"],
            swiftSettings: appTargetSettings
        )
    ]
)

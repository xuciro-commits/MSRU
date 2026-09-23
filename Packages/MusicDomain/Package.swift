// swift-tools-version: 6.0

import PackageDescription

// Music domain: product-specific types and toolkits for MSRU.
// Nothing here may be imported by AppFoundation or by platform-level code.
//
// Transitional (#75 → #76): the target also declares the Music-side
// third-party/local packages (GRDB, ChromaSwift, MediaLibrary, SubsonicKit)
// so the app keeps linking them after they were removed from AppFoundation.
// #76 moves the Music code that actually uses them into this package.
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
        .library(name: "MusicDomain", targets: ["MusicDomain"])
    ],

    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.11.0"),
        .package(path: "../ChromaSwift"),
        .package(path: "../MediaLibrary"),
        .package(path: "../SubsonicKit")
    ],

    targets: [
        .target(
            name: "MusicDomain",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "ChromaSwift", package: "ChromaSwift"),
                .product(name: "MediaLibrary", package: "MediaLibrary"),
                .product(name: "SubsonicKit", package: "SubsonicKit")
            ]
        ),
        .testTarget(
            name: "MusicDomainTests",
            dependencies: ["MusicDomain"]
        )
    ]
)

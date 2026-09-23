// swift-tools-version: 6.0

import PackageDescription


let package = Package(
    name: "AppFoundation",
    defaultLocalization: "en",

    platforms: [
        .macOS("27.0"),
        .iOS("27.0"),
        .tvOS("27.0"),
        .watchOS("27.0"),
        .visionOS("27.0")
    ],

    products: [

        // MARK: - Core

        .library(
            name: "AppFoundation",
            targets: [
                "AppFoundation"
            ]
        ),


        // MARK: - UI

        .library(
            name: "AppFoundationUI",
            targets: [
                "AppFoundationUI"
            ]
        )
    ],

    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.11.0"),
        .package(path: "../ChromaSwift"),
        .package(path: "../MediaLibrary"),
        .package(path: "../SubsonicKit")
    ],

    targets: [

        // MARK: - Core

        .target(
            name: "AppFoundation",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "ChromaSwift", package: "ChromaSwift"),
                .product(name: "MediaLibrary", package: "MediaLibrary"),
                .product(name: "SubsonicKit", package: "SubsonicKit")
            ],
            resources: [
                .process("Resources")
            ]
        ),


        // MARK: - UI

        .target(
            name: "AppFoundationUI",
            dependencies: [
                "AppFoundation"
            ],
            resources: [
                .process("Resources")
            ]
        ),


        // MARK: - Tests
        .testTarget(
            name: "AppFoundationTests",
            dependencies: [
                "AppFoundation"
            ]
        ),

        .testTarget(
            name: "AppFoundationUITests",
            dependencies: [
                "AppFoundation",
                "AppFoundationUI"
            ]
        )
    ]
)

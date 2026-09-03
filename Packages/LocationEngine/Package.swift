// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LocationEngine",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "LocationEngine", targets: ["LocationEngine"]),
    ],
    dependencies: [
        .package(path: "../GeoData"),
    ],
    targets: [
        .target(
            name: "LocationEngine",
            dependencies: ["GeoData"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "LocationEngineTests",
            dependencies: ["LocationEngine"],
            resources: [
                // Synthetic pack (copied from GeoData) + hand-authored GPX traces.
                .copy("Fixtures/tr.pack"),
                .copy("Fixtures/gpx"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)

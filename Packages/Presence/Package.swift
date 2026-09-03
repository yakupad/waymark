// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Presence",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "Presence", targets: ["Presence"]),
    ],
    dependencies: [
        .package(path: "../GeoData"),
        .package(path: "../LocationEngine"),
        .package(path: "../TripKit"),
    ],
    targets: [
        .target(
            name: "Presence",
            dependencies: ["GeoData", "LocationEngine", "TripKit"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "PresenceTests",
            dependencies: ["Presence"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TripKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "TripKit", targets: ["TripKit"]),
    ],
    dependencies: [
        .package(path: "../GeoData"),
        // Spec graph 6.2: TripKit → LocationEngine (for `PlaceEvent` in `Trip`).
        .package(path: "../LocationEngine"),
    ],
    targets: [
        .target(
            name: "TripKit",
            dependencies: ["GeoData", "LocationEngine"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "TripKitTests",
            dependencies: ["TripKit"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GeoData",
    platforms: [
        // The app targets iOS 27 (spec Section 17.2). The package floor is lower so the
        // pure-Swift geometry code can also be exercised by `swift test` on macOS.
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "GeoData", targets: ["GeoData"]),
    ],
    dependencies: [
        // Locked decision (spec K3 / Section 17.3): GRDB for the pack reader — mature
        // R*Tree support, Sendable/concurrency friendly, one clean SPM dependency.
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "GeoData",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "GeoDataTests",
            dependencies: ["GeoData"],
            resources: [
                // Synthetic pack produced by `tools/build_pack.py --fixture`
                // (see Fixtures/README.md for how to regenerate).
                .copy("Fixtures/tr.pack"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)

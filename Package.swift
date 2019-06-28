// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "FetchRequests",
    platforms: [
        .macOS(.v10_12),
        .iOS(.v10),
        .tvOS(.v10),
        .watchOS(.v3),
    ],
    products: [
        .library(
            name: "FetchRequests",
            targets: ["FetchRequests"]
        ),
    ],
    targets: [
        .target(
            name: "FetchRequests",
            path: "FetchRequests"
        ),
    ],
    swiftLanguageVersions: [.v5]
)

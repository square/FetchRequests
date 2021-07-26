// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "FetchRequests",
    platforms: [
        .macOS(.v10_15),
        .macCatalyst(.v13),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
    ],
    products: [
        .library(
            name: "FetchRequests",
            targets: ["FetchRequests"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections", from: "0.0.4"),
    ],
    targets: [
        .target(
            name: "FetchRequests",
            dependencies: [
                .product(name: "Collections", package: "swift-collections"),
            ],
            path: "FetchRequests",
            exclude: ["Tests"]
        ),
        .testTarget(
            name: "FetchRequestsTests",
            dependencies: ["FetchRequests"],
            path: "FetchRequests/Tests"
        ),
    ],
    swiftLanguageVersions: [.v5]
)

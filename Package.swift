// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "FetchRequests",
    platforms: [
        .macCatalyst(.v14),
        .iOS(.v14),
        .tvOS(.v14),
        .watchOS(.v7),
        .macOS(.v11),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "FetchRequests",
            targets: ["FetchRequests"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "FetchRequests",
            dependencies: [
                .product(name: "Collections", package: "swift-collections"),
            ],
            path: "FetchRequests",
            exclude: ["Tests", "Info.plist", "TestsInfo.plist"]
        ),
        .testTarget(
            name: "FetchRequestsTests",
            dependencies: ["FetchRequests"],
            path: "FetchRequests/Tests"
        ),
    ],
    swiftLanguageVersions: [.v5]
)

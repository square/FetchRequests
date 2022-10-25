// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "FetchRequests",
    platforms: [
        .macCatalyst(.v13),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
        .macOS(.v10_15),
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

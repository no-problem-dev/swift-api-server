// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "APIServer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "APIServer",
            targets: ["APIServer"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/no-problem-dev/swift-api-contract.git", from: "1.0.0"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.99.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin.git", from: "1.4.0"),
    ],
    targets: [
        .target(
            name: "APIServer",
            dependencies: [
                .product(name: "APIContract", package: "swift-api-contract"),
                .product(name: "Vapor", package: "vapor"),
            ]
        ),
        .testTarget(
            name: "APIServerTests",
            dependencies: [
                "APIServer",
                .product(name: "XCTVapor", package: "vapor"),
            ],
            path: "Tests"
        )
    ]
)

// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DeenAssist",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "DeenAssist",
            targets: ["DeenAssist"]
        ),
    ],
    dependencies: [
        // AdhanSwift for prayer time calculations
        .package(url: "https://github.com/batoulapps/adhan-swift", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "DeenAssist",
            dependencies: [
                .product(name: "Adhan", package: "adhan-swift")
            ]
        ),
        .testTarget(
            name: "DeenAssistTests",
            dependencies: ["DeenAssist"]
        ),
    ]
)

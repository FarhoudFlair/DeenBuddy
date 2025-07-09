// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DeenBuddy",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "DeenAssistCore",
            targets: ["DeenAssistCore"]),
        .library(
            name: "DeenAssistUI",
            targets: ["DeenAssistUI"]),
        .library(
            name: "DeenAssistProtocols",
            targets: ["DeenAssistProtocols"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0"),
        .package(url: "https://github.com/batoulapps/Adhan-Swift.git", from: "1.4.0"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture.git", from: "1.0.0"),
        .package(url: "https://github.com/Swinject/Swinject.git", from: "2.8.0"),
        .package(name: "QiblaKit", path: "./QiblaKit")
    ],
    targets: [
        .target(
            name: "DeenAssistCore",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
                .product(name: "Adhan", package: "Adhan-Swift"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                "Swinject",
                "DeenAssistProtocols",
                .product(name: "QiblaKit", package: "QiblaKit")
            ],
            path: "Sources/DeenAssistCore",
            resources: [
                .process("Localization/Resources")
            ]),
        .target(
            name: "DeenAssistUI",
            dependencies: ["DeenAssistCore"],
            path: "Sources/DeenAssistUI"),
        .target(
            name: "DeenAssistProtocols",
            dependencies: [],
            path: "Sources/DeenAssistProtocols"),
        .testTarget(
            name: "DeenAssistCoreTests",
            dependencies: ["DeenAssistCore"]),
    ]
)

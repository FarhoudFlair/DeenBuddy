// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DeenBuddyCore",
    platforms: [
        .iOS(.v16)  // iOS only - removed macOS support
    ],
    products: [
        .library(
            name: "DeenBuddyCore",
            targets: ["DeenBuddyCore"]
        )
    ],
    dependencies: [
        // Existing working dependencies
        .package(
            url: "https://github.com/batoulapps/adhan-swift",
            from: "1.0.0"
        ),
        .package(
            url: "https://github.com/supabase/supabase-swift",
            from: "2.0.0"
        ),

        // iOS-specific dependencies
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            from: "1.0.0"
        )
    ],
    targets: [
        .target(
            name: "DeenBuddyCore",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
                .product(name: "Adhan", package: "adhan-swift"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ],
            path: "Sources/DeenAssistCore"
        ),
        .testTarget(
            name: "DeenBuddyCoreTests",
            dependencies: ["DeenBuddyCore"],
            path: "Tests/DeenAssistCoreTests"
        )
    ]
)

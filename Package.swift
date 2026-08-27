// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "foundation-dependencies",
    platforms: [
        .iOS(.v16),
        .tvOS(.v16),
        .macOS(.v13),
        .watchOS(.v9)
    ],
    products: [
        .library(
            name: "FoundationDependencies",
            targets: ["FoundationDependencies"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-dependencies.git", .upToNextMinor(from: "1.8.1")),
        .package(url: "https://github.com/nashysolutions/versioning.git", .upToNextMinor(from: "2.1.0")),
        .package(url: "https://github.com/nashysolutions/files.git", .upToNextMinor(from: "3.0.0")),

        // Already in the graph beneath swift-dependencies, which re-exports
        // `IssueReporting` from `Dependencies`. Declared directly anyway, because
        // `UserDefaultsClient` calls `reportIssue` in its own source and a re-export
        // somebody else owns is not a dependency this package should rely on.
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay.git", .upToNextMinor(from: "1.5.2"))
    ],
    targets: [
        .target(
            name: "FoundationDependencies",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),

                // `@DependencyClient` on `UserDefaultsClient`. Macros need a 5.9
                // compiler, not a 5.9 manifest, so the tools version above stays at
                // 5.7 and this package stays in the Swift 5 language mode. Raising it
                // to 6.0 would move the library into the Swift 6 language mode and
                // turn the remaining Sendable warnings in the graph into errors, which
                // is a separate decision from using a macro.
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
                .product(name: "Versioning", package: "versioning"),
                .product(name: "Files", package: "files")
            ]
        ),
        .testTarget(
            name: "FoundationDependenciesTests",
            dependencies: [
                "FoundationDependencies",

                // Not optional. Without it, `IssueReporting` records a Swift Testing
                // issue through an unsafe fallback that reads uninitialised memory,
                // and the test process dies with SIGBUS in `outlined destroy of Issue`
                // the first time an unimplemented endpoint is called. Measured on
                // Swift 6.2.4, macOS arm64, before this line was added.
                .product(name: "IssueReportingTestSupport", package: "xctest-dynamic-overlay")
            ]
        )
    ]
)

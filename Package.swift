// swift-tools-version: 5.4

import PackageDescription

let package = Package(
    name: "foundation-dependencies",
    platforms: [
        .iOS(.v13),
        .tvOS(.v12),
        .macOS(.v11),
        .watchOS(.v4)
    ],
    products: [
        .library(
            name: "FoundationDependencies",
            targets: ["FoundationDependencies"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-dependencies.git", .upToNextMinor(from: "1.8.1")),
        .package(url: "https://github.com/nashysolutions/versioning.git", .upToNextMinor(from: "2.1.0"))
    ],
    targets: [
        .target(
            name: "FoundationDependencies",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Versioning", package: "versioning")
            ]
        )
    ]
)

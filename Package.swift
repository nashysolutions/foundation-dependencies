// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "foundation-dependencies",
    platforms: [
        .iOS(.v16),
        .tvOS(.v13),
        .macOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "FoundationDependencies",
            targets: ["FoundationDependencies"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-dependencies.git", .upToNextMinor(from: "1.8.1")),
        .package(url: "https://github.com/nashysolutions/versioning.git", .upToNextMinor(from: "2.1.0")),
        .package(url: "https://github.com/nashysolutions/files.git", .upToNextMinor(from: "2.0.0"))
    ],
    targets: [
        .target(
            name: "FoundationDependencies",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Versioning", package: "versioning"),
                .product(name: "Files", package: "files")
            ]
        )
    ]
)

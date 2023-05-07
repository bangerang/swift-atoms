// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Atoms",
    platforms: [.iOS(.v13), .macOS(.v10_15)],
    products: [
        .library(
            name: "Atoms",
            targets: ["Atoms"]),
    ],
    dependencies: [
        .package(url: "https://github.com/bangerang/swift-async-expectations.git", from: "0.1.0"),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "0.3.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.1.0"),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "0.2.0")
    ],
    targets: [
        .target(
            name: "Atoms",
            dependencies: [
                .product(name: "CustomDump", package: "swift-custom-dump"),
                .product(name: "AsyncExpectations", package: "swift-async-expectations")
            ]
        ),
        .testTarget(
            name: "AtomsTests",
            dependencies: ["Atoms", .product(name: "AsyncExpectations", package: "swift-async-expectations")]),
    ]
)

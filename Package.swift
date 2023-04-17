// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Atoms",
    platforms: [.iOS(.v13), .macOS(.v10_15)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Atoms",
            targets: ["Atoms"]),
        .library(
            name: "AtomsTesting",
            type: .dynamic,
            targets: ["AtomsTesting"]),
    ],
    dependencies: [
        .package(url: "https://github.com/bangerang/swift-async-expectations.git", from: "0.0.1"),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "0.3.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.1.0"),
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "Atoms",
            dependencies: [.product(name: "CustomDump", package: "swift-custom-dump")]
        ),
        .target(name: "AtomsTesting", dependencies: [
            .product(name: "AsyncExpectations", package: "swift-async-expectations"), "Atoms"
        ]),
        .testTarget(
            name: "AtomsTests",
            dependencies: ["Atoms", .product(name: "AsyncExpectations", package: "swift-async-expectations")]),
    ]
)

// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "api",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .executable(
            name: "api",
            targets: [ "api" ]),
        .library(
            name: "ServerCore",
            targets: ["ServerCore"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "0.3.2")),
        .package(url: "https://github.com/Kitura/Kitura.git", .upToNextMajor(from: "2.9.200")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "api",
            dependencies: [
                "ServerCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]),
        .target(
            name: "ServerCore",
            dependencies: [ "Kitura" ]),
        .testTarget(
            name: "apiTests",
            dependencies: ["api"]),
    ]
)

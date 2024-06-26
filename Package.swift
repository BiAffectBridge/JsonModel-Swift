// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "JsonModel",
    platforms: [
        // Add support for all platforms starting from a specific version.
        .macOS(.v11),
        .iOS(.v14),
        .watchOS(.v6),
        .tvOS(.v14)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "JsonModel",
            targets: ["JsonModel", "ResultModel"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "JsonModel",
            dependencies: []),
        .testTarget(
            name: "JsonModelTests",
            dependencies: ["JsonModel"]),
        
        .target(
            name: "ResultModel",
            dependencies: ["JsonModel"]),
        .testTarget(
            name: "ResultModelTests",
            dependencies: ["ResultModel"]),
    ]
)

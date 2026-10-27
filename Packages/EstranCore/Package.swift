// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EstranCore",
    platforms: [
        .iOS("27.0"),
        .macOS(.v14)
    ],
    products: [
        .library(name: "EstranCore", targets: ["EstranCore"])
    ],
    targets: [
        .target(
            name: "EstranCore",
            path: "Sources/EstranCore",
            resources: [
                .process("Resources")
            ]),
        .testTarget(
            name: "EstranCoreTests",
            dependencies: ["EstranCore"],
            path: "Tests/EstranCoreTests")
    ],
    swiftLanguageModes: [.v6])

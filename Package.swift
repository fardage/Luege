// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Luege",
    platforms: [
        .tvOS(.v17),
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LuegeCore",
            targets: ["LuegeCore"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/amosavian/AMSMB2.git", from: "4.0.0")
    ],
    targets: [
        .target(
            name: "LuegeCore",
            dependencies: ["AMSMB2"],
            path: "Sources/LuegeCore"
        ),
        .testTarget(
            name: "LuegeCoreTests",
            dependencies: ["LuegeCore"],
            path: "Tests/LuegeCoreTests"
        ),
        .testTarget(
            name: "LuegeIntegrationTests",
            dependencies: ["LuegeCore"],
            path: "Tests/LuegeIntegrationTests"
        )
    ]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LiteMonk",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        .target(
            name: "LiteMonkCore",
            path: "Sources/LiteMonkCore"
        ),
        .executableTarget(
            name: "litemonk",
            dependencies: ["LiteMonkCore", .product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/App",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "LiteMonkAppTests",
            dependencies: ["litemonk"],
            path: "Tests/LiteMonkAppTests"
        ),
    ]
)

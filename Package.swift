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
            resources: [
                .process("Resources/Dhammapada.json"),
                .process("Resources/Dhammapada_vi.txt"),
                .process("Resources/Lotus.svg"),
                .process("Resources/bell.mp3"),
                .process("Resources/bonk_1.mp3"),
                .process("Resources/donate-vietqr.png"),
                .copy("Resources/an-mo"),
                .copy("Resources/Voices")
            ]
        ),
        .testTarget(
            name: "LiteMonkAppTests",
            dependencies: ["litemonk"],
            path: "Tests/LiteMonkAppTests"
        ),
    ]
)

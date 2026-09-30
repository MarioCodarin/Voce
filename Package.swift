// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Voce",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Voce", targets: ["Voce"])
    ],
    targets: [
        // Transcription logic: audio, network, CLI. No AppKit, so it is unit-testable.
        .target(
            name: "VoceKit",
            path: "Sources/VoceKit"
        ),
        // The Mac app: window, views, menu. Depends only on VoceKit's public API.
        .executableTarget(
            name: "Voce",
            dependencies: ["VoceKit"],
            path: "Sources/Voce"
        ),
        .testTarget(
            name: "VoceKitTests",
            dependencies: ["VoceKit"],
            path: "Tests/VoceKitTests"
        )
    ]
)

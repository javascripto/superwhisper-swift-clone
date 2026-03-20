// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "WhisperOverlay",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "WhisperOverlayApp",
            targets: ["WhisperOverlayApp"]
        )
    ],
    targets: [
        .executableTarget(
            name: "WhisperOverlayApp",
            path: "Sources/WhisperOverlayApp"
        )
    ]
)

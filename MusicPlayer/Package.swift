// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "MusicPlayer",
    platforms: [
        .macOS(.v10_15)
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MusicPlayer",
            dependencies: []
        )
    ]
)

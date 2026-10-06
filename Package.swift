// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Spanorama",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .target(
            name: "SpanoramaKit",
            path: "Sources/SpanoramaKit"
        ),
        .executableTarget(
            name: "Spanorama",
            dependencies: ["SpanoramaKit"],
            path: "Sources/Spanorama"
        ),
        .executableTarget(
            name: "SpanoramaTests",
            dependencies: ["SpanoramaKit"],
            path: "Sources/SpanoramaTests"
        )
    ]
)

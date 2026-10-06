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
            path: "Sources/Spanorama",
            // SwiftPM stamps the SDK version in LC_BUILD_VERSION as the deployment
            // target (14.0); macOS only enables the modern Liquid Glass appearance
            // when the stamped SDK is 26+. Force the real SDK version at link time.
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-platform_version", "-Xlinker", "macOS", "-Xlinker", "14.0", "-Xlinker", "27.0"])
            ]
        ),
        .executableTarget(
            name: "SpanoramaTests",
            dependencies: ["SpanoramaKit"],
            path: "Sources/SpanoramaTests"
        )
    ]
)

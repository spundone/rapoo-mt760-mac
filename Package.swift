// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MTControl",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "MTControl",
            path: "Sources/MTControl",
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [.linkedFramework("IOKit")]
        ),
        .testTarget(
            name: "MTControlTests",
            dependencies: ["MTControl"],
            path: "Tests/MTControlTests"
        ),
    ]
)

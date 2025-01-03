// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "IMStatus",
    platforms: [
        .macOS(.v12)
    ],
    targets: [
        .executableTarget(
            name: "IMStatus",
            dependencies: []
        )
    ]
) 
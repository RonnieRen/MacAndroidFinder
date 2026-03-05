// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DroidFinder",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "DroidFinder",
            targets: ["DroidFinder"]
        )
    ],
    targets: [
        .executableTarget(
            name: "DroidFinder"
        )
    ]
)

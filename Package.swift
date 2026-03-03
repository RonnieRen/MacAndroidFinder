// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "AndroidBridgeApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "AndroidBridgeApp",
            targets: ["AndroidBridgeApp"]
        )
    ],
    targets: [
        .executableTarget(
            name: "AndroidBridgeApp"
        )
    ]
)

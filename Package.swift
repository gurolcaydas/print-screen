// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PrintScreenApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "PrintScreenApp", targets: ["PrintScreenApp"])
    ],
    targets: [
        .executableTarget(
            name: "PrintScreenApp",
            path: "Sources"
        )
    ]
)

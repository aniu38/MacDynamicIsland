// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacDynamicIsland",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "MacDynamicIsland",
            targets: ["MacDynamicIsland"]
        )
    ],
    targets: [
        .executableTarget(
            name: "MacDynamicIsland",
            path: "Sources"
        )
    ]
)

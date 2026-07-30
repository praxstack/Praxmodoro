// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PraxmodoroStore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "PraxmodoroStore", targets: ["PraxmodoroStore"])
    ],
    dependencies: [
        .package(path: "../PraxmodoroCore")
    ],
    targets: [
        .target(name: "PraxmodoroStore", dependencies: ["PraxmodoroCore"]),
        .testTarget(name: "PraxmodoroStoreTests", dependencies: ["PraxmodoroStore"])
    ]
)

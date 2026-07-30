// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PraxmodoroCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "PraxmodoroCore", targets: ["PraxmodoroCore"])
    ],
    targets: [
        .target(name: "PraxmodoroCore"),
        .testTarget(name: "PraxmodoroCoreTests", dependencies: ["PraxmodoroCore"])
    ]
)

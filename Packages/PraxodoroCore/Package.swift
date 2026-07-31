// swift-tools-version: 6.2

import PackageDescription

let strictSwiftSettings: [SwiftSetting] = [
  .swiftLanguageMode(.v6),
  .treatAllWarnings(as: .error),
]

let package = Package(
  name: "PraxodoroCore",
  platforms: [.macOS("26.0")],
  products: [
    .library(name: "PraxodoroCore", targets: ["PraxodoroCore"])
  ],
  targets: [
    .target(name: "PraxodoroCore", swiftSettings: strictSwiftSettings),
    .testTarget(
      name: "PraxodoroCoreTests",
      dependencies: ["PraxodoroCore"],
      swiftSettings: strictSwiftSettings
    ),
  ]
)

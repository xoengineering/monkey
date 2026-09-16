// swift-tools-version: 6.4
import PackageDescription

let package = Package(
  name: "Monkey",
  platforms: [
    .macOS(.v27),
    .iOS(.v27),
  ],
  products: [
    .library(name: "MonkeyCore", targets: ["MonkeyCore"]),
    .library(name: "MonkeyUI", targets: ["MonkeyUI"]),
    .executable(name: "monkey", targets: ["monkey"]),
  ],
  dependencies: [
    .package(url: "https://github.com/jpsim/Yams.git", exact: "6.2.2"),
    .package(url: "https://github.com/gonzalezreal/textual.git", exact: "0.5.0"),
    .package(url: "https://github.com/apple/swift-argument-parser.git", exact: "1.8.2"),
  ],
  targets: [
    .target(
      name: "MonkeyCore",
      dependencies: [
        .product(name: "Yams", package: "Yams")
      ]
    ),
    .target(
      name: "MonkeyUI",
      dependencies: [
        "MonkeyCore",
        .product(name: "Textual", package: "textual"),
      ]
    ),
    .executableTarget(
      name: "monkey",
      dependencies: [
        "MonkeyCore",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]
    ),
    .testTarget(
      name: "MonkeyCoreTests",
      dependencies: ["MonkeyCore"]
    ),
    .testTarget(
      name: "MonkeyUITests",
      dependencies: ["MonkeyUI"]
    ),
  ]
)

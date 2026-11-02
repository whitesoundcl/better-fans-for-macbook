// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "better-fans-for-macbook",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "FanCore", targets: ["FanCore"]),
        .executable(name: "fanctl", targets: ["fanctl"]),
        .executable(name: "fanhelperd", targets: ["fanhelperd"]),
        .executable(name: "BetterFans", targets: ["BetterFans"]),
    ],
    targets: [
        .target(name: "FanCore"),
        .executableTarget(name: "fanctl", dependencies: ["FanCore"]),
        .executableTarget(name: "fanhelperd", dependencies: ["FanCore"]),
        .executableTarget(name: "BetterFans", dependencies: ["FanCore"]),
        .testTarget(name: "FanCoreTests", dependencies: ["FanCore"]),
    ]
)

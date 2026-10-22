// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ThreeFingerLookup",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LookupText", targets: ["LookupText"]),
        .executable(name: "ThreeFingerLookup", targets: ["ThreeFingerLookup"])
    ],
    targets: [
        .target(name: "LookupText"),
        .executableTarget(
            name: "ThreeFingerLookup",
            dependencies: ["LookupText"],
            path: "Sources/ThreeFingerLookup"
        ),
        .testTarget(name: "LookupTextTests", dependencies: ["LookupText"])
    ]
)

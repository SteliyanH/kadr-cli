// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "kadr-cli",
    // A Mac tool: kadr is AVFoundation, so there is nothing to run on Linux.
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "kadr", targets: ["KadrCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SteliyanH/kadr.git", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    ],
    targets: [
        // Everything the commands do, kept out of the executable so the tests
        // can call it. The executable only parses arguments and prints.
        .target(
            name: "KadrCLIKit",
            dependencies: [
                .product(name: "Kadr", package: "kadr"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // Not named "kadr": on a case-insensitive disk its module would collide
        // with kadr's `Kadr` in the build directory. The product is still `kadr`.
        .executableTarget(
            name: "KadrCLI",
            dependencies: [
                "KadrCLIKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "KadrCLIKitTests",
            dependencies: [
                "KadrCLIKit",
                .product(name: "Kadr", package: "kadr"),
            ]
        ),
    ]
)

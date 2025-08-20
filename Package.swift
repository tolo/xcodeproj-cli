// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "xcodeproj-cli",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(
            name: "xcodeproj-cli",
            targets: ["xcodeproj-cli"]
        ),
    ],
    dependencies: [
        // Using exact version 9.4.3 which provides full product reference functionality
        // TODO: Update to 9.5.0+ when XcodeProj becomes Swift 6 compatible
        .package(url: "https://github.com/tuist/XcodeProj.git", exact: "9.4.3"),
        .package(url: "https://github.com/kylef/PathKit.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "xcodeproj-cli",
            dependencies: [
                "XcodeProj",
                "PathKit"
            ],
            path: "Sources/xcodeproj-cli"
        ),
        .testTarget(
            name: "xcodeproj-cliTests",
            dependencies: ["xcodeproj-cli"],
            path: "Tests/xcodeproj-cliTests",
            exclude: [
                "TestResources"
            ]
        ),
    ]
)
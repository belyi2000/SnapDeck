// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SnapDeck",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SnapDeck", targets: ["SnapDeck"]),
        .executable(name: "SnapDeckChecks", targets: ["SnapDeckChecks"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .target(
            name: "SnapDeckMultitouch",
            path: "Sources/SnapDeckMultitouch",
            publicHeadersPath: "include"
        ),
        .target(
            name: "SnapDeckCore",
            path: "Sources/SnapDeckCore",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
                .linkedFramework("ScreenCaptureKit")
            ]
        ),
        .executableTarget(
            name: "SnapDeck",
            dependencies: [
                "SnapDeckCore",
                "SnapDeckMultitouch",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/SnapDeck"
        ),
        .executableTarget(
            name: "SnapDeckChecks",
            dependencies: ["SnapDeckCore"],
            path: "Tests/SnapDeckChecks"
        )
    ]
)

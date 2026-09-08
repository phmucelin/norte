// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NorteKit",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "NorteKit", targets: ["NorteKit"])
    ],
    targets: [
        .target(
            name: "NorteKit",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "NorteKitTests",
            dependencies: ["NorteKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)

// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "PCCat",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "PCCat",
            path: "Sources/PCCat",
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
            ]
        )
    ]
)

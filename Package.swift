// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "apfel",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "apfel",
            path: "Sources"
        )
    ]
)

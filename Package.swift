// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GitMenuBar",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "GitMenuBar",
            path: "GitMenuBar",
            exclude: ["Info.plist"]
        )
    ]
)

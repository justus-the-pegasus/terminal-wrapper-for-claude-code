// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeCode",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "ClaudeCode",
            dependencies: ["SwiftTerm"]
        )
    ]
)
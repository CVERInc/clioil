// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "clioil",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "ClioilCore", targets: ["ClioilCore"]),
        .executable(name: "clioil", targets: ["clioil"]),
        .executable(name: "ClioilApp", targets: ["ClioilApp"]),
    ],
    targets: [
        // Pure engine: scanning, the Publisher plugin seam, npm implementation.
        // No UI, no global state — drives equally well from a CLI or a SwiftUI app.
        .target(name: "ClioilCore"),
        // Thin CLI shell over the engine. First vertical slice: `clioil list`.
        .executableTarget(name: "clioil", dependencies: ["ClioilCore"]),
        // SwiftUI app over the same engine — the native "click to ship" surface.
        .executableTarget(name: "ClioilApp", dependencies: ["ClioilCore"]),
        // Dependency-free test runner so `swift run ClioilTests` works on plain
        // Command Line Tools (XCTest/swift-testing need full Xcode). Migrate to
        // swift-testing once CI/Xcode is in the picture.
        .executableTarget(name: "ClioilTests", dependencies: ["ClioilCore"]),
    ]
)

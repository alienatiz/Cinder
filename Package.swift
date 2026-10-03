// swift-tools-version: 6.4
import PackageDescription
import Foundation

// Keep the audio migration reviewable: diagnose all concurrency issues in Swift
// 5 mode, and exercise Swift 6 separately with Check-Xcode.command swift6.
let checkSwift6 = ProcessInfo.processInfo.environment["CINDER_SWIFT6"] == "1"
let concurrency: [SwiftSetting] = checkSwift6 ? [] : [.enableUpcomingFeature("StrictConcurrency")]

let package = Package(
    name: "Cinder",
    platforms: [.macOS("14.0")],
    products: [.executable(name: "Cinder", targets: ["CinderApp"])],
    dependencies: [.package(url: "https://github.com/jpsim/Yams.git", exact: "6.2.2")],
    targets: [
        .target(name: "CinderCore", swiftSettings: concurrency),
        .target(name: "CinderDSP", publicHeadersPath: "include", cSettings: [.unsafeFlags(["-std=c11"])]),
        .target(name: "CinderPlatform", dependencies: ["CinderCore"], swiftSettings: concurrency, linkerSettings: [.linkedFramework("CoreAudio"), .linkedFramework("IOKit"), .linkedFramework("UserNotifications")]),
        .target(name: "CinderAudio", dependencies: ["CinderCore", "CinderDSP", "CinderPlatform"], swiftSettings: concurrency, linkerSettings: [.linkedFramework("AVFoundation"), .linkedFramework("AudioToolbox")]),
        .target(name: "CinderStorage", dependencies: ["CinderCore", .product(name: "Yams", package: "Yams")], swiftSettings: concurrency),
        .executableTarget(name: "CinderApp", dependencies: ["CinderCore", "CinderAudio", "CinderPlatform", "CinderStorage"], resources: [.process("Resources")], swiftSettings: concurrency),
        .testTarget(name: "CinderCoreTests", dependencies: ["CinderCore", "CinderDSP", "CinderStorage", "CinderAudio", "CinderPlatform"], resources: [.copy("Fixtures")], swiftSettings: concurrency),
        .testTarget(name: "CinderAppTests", dependencies: ["CinderApp", "CinderCore", "CinderStorage", "CinderPlatform"], swiftSettings: concurrency)
    ],
    swiftLanguageModes: checkSwift6 ? [.v6] : [.v5]
)

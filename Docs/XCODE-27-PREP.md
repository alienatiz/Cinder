# macOS 27 Golden Gate / Xcode 27 — 1.0.0 baseline

Baseline recorded on 2026-09-23. The minimum runtime and test target is macOS 27.0;
the build architecture is arm64. `Package.swift`, generated app Info.plist values,
and build preflight checks use the same baseline.

Apple's Xcode 27 table specifies Swift 6.4 and the macOS 27 SDK, with both Swift 5
and Swift 6 language modes. Xcode itself can run on macOS 26.6 or later, but this
project's test-and-build commands require macOS 27 because that is the deployment
target. macOS 27 targets Apple Silicon. Dropping Intel is a choice for this
development line, not a claim that Xcode forbids Intel builds for all older systems.

## Checks

`bash Check-Xcode.command` verifies the selected Xcode 27.x, SDK 27.x, Swift 6.x
compiler at version 6.4 or later, native arm64 execution, and host OS. It checks
app/deployment metadata and music hashes, then builds and runs XCTest. It respects
`DEVELOPER_DIR` without changing global `xcode-select` settings.

`bash Check-Xcode.command swift6` uses `.build/compatibility-swift6/package` and
`CINDER_SWIFT6=1` to check Swift 6 language mode separately. The default uses Swift 5
with StrictConcurrency diagnostics. Language mode is separate from compiler and
SDK versions. Review concurrency warnings even when the Swift 5 build exits with 0.

Each path writes `toolchain.txt`, `build.log`, `tests.log`, and `result.txt`.
Automated builds do not validate live device output, UI behavior, or long-duration
energy use. Do not mark those as supported without execution evidence.

## Remaining review

- RenderKernel's unchecked Sendable conformance, preparation cancellation, C buffer ownership, and AVAudioEngine configuration notifications.
- MainRunLoopTicker actor isolation and teardown; device observation and UI task cleanup.
- AVAudioConverter handling of external music and all seven presets, playback boundaries, and device disconnection.
- Gain, duration, music, and theme restoration from older settings on a real Mac, without automatic playback.
- Light/Dark/System appearance, minimum window size, three languages, popup focus/hover, and onChange/activation behavior.

References: [Xcode requirements](https://developer.apple.com/xcode/system-requirements),
[Xcode 27 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes),
[macOS 27 release notes](https://developer.apple.com/documentation/macos-release-notes/macos-27-release-notes),
and [Swift concurrency checking](https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/enabledataracesafety/).

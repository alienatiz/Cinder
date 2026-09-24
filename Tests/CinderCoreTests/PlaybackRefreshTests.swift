import XCTest
import Combine
import CinderCore
import CinderPlatform

final class PlaybackRefreshTests: XCTestCase {
    @MainActor func testUnchangedSnapshotsDoNotPublishRepeatedly() {
        let display = PlaybackDisplay()
        var notifications = 0
        let subscription = display.objectWillChange.sink { notifications += 1 }
        for _ in 0..<10_000 { display.update(AudioSnapshot()) }
        XCTAssertEqual(notifications, 0)
        var next = AudioSnapshot(); next.elapsed = 10
        display.update(next)
        for _ in 0..<10_000 { display.update(next) }
        XCTAssertEqual(notifications, 1)
        XCTAssertEqual(display.snapshot.elapsed, 10)
        withExtendedLifetime(subscription) {}
    }
    @MainActor func testTickerStopsAndReleasesOwner() async throws {
        var ticker: MainRunLoopTicker? = MainRunLoopTicker()
        weak let weakTicker = ticker
        var calls = 0
        for _ in 0..<100 { ticker?.start(interval: 0.01) { calls += 1 } }
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertGreaterThan(calls, 0)
        ticker?.stop()
        let stoppedAt = calls
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(calls, stoppedAt)
        ticker?.start(interval: 0.01) { calls += 1 }
        ticker = nil
        XCTAssertNil(weakTicker)
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(calls, stoppedAt)
    }
}

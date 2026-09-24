import XCTest
import CinderCore
import CinderStorage
import CinderPlatform
@testable import CinderApp

@MainActor private final class NotificationSpy: SessionNotifying {
    var status: NotificationPermission = .notRequested
    var grant = true
    var requests = 0
    var sent: [String] = []
    var failSend = false
    func permission() async -> NotificationPermission { status }
    func requestPermission() async throws -> Bool { requests += 1; status = grant ? .allowed : .denied; return grant }
    func send(identifier: String, title: String, body: String) async throws {
        if failSend { throw CinderError.audio("Simulated notification failure") }
        sent.append(identifier)
    }
}

final class NotificationIntegrationTests: XCTestCase {
    @MainActor func testPermissionOnlyRequestedWhenEnabledAndDenialKeepsHistory() async throws {
        let store = SettingsStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let spy = NotificationSpy(); spy.grant = false
        let model = AppModel(storage: store, notifications: spy)
        defer { model.shutdown(); try? FileManager.default.removeItem(at: store.directory) }
        XCTAssertEqual(spy.requests, 0); XCTAssertFalse(model.notificationsEnabled)
        await model.setNotificationsEnabled(true)
        XCTAssertEqual(spy.requests, 1); XCTAssertFalse(model.notificationsEnabled)
        model.beginSessionRecord(); model.finishSessionRecord(.completed)
        await model.notificationTask?.value
        XCTAssertTrue(spy.sent.isEmpty)
        XCTAssertEqual(model.sessionHistory.records.first?.outcome, .completed)
        await model.setNotificationsEnabled(true)
        XCTAssertEqual(spy.requests, 1)
    }
    @MainActor func testOnlyActionableOutcomesNotifyAndDisablePersists() async throws {
        let store = SettingsStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let spy = NotificationSpy(); let model = AppModel(storage: store, notifications: spy)
        defer { model.shutdown(); try? FileManager.default.removeItem(at: store.directory) }
        await model.setNotificationsEnabled(true)
        XCTAssertTrue(try store.loadNotificationPreferences().enabled)
        for outcome in [SessionOutcome.completed, .stopped, .appQuit, .interrupted, .deviceChanged, .failed, .missedSchedule] {
            model.beginSessionRecord(); model.finishSessionRecord(outcome)
            await model.notificationTask?.value
        }
        XCTAssertEqual(spy.sent.count, 4); XCTAssertEqual(Set(spy.sent).count, 4)
        model.finishSessionRecord(.completed); await model.notificationTask?.value
        XCTAssertEqual(spy.sent.count, 4)
        await model.setNotificationsEnabled(false)
        XCTAssertFalse(try store.loadNotificationPreferences().enabled)
        model.beginSessionRecord(); model.finishSessionRecord(.completed); await model.notificationTask?.value
        XCTAssertEqual(spy.sent.count, 4)
    }
    @MainActor func testDeliveryFailureDoesNotEraseRecordOrChangePlayback() async throws {
        let store = SettingsStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let spy = NotificationSpy(); spy.failSend = true
        let model = AppModel(storage: store, notifications: spy)
        defer { model.shutdown(); try? FileManager.default.removeItem(at: store.directory) }
        await model.setNotificationsEnabled(true)
        model.beginSessionRecord(); model.state = .completed; model.finishSessionRecord(.completed)
        await model.notificationTask?.value
        XCTAssertFalse(model.notificationMessage.isEmpty)
        XCTAssertEqual(model.state, .completed)
        XCTAssertEqual(model.sessionHistory.records.first?.outcome, .completed)
    }
}

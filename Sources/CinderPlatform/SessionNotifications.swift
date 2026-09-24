import Foundation
import UserNotifications

public enum NotificationPermission: Sendable { case notRequested, allowed, denied, unavailable }

@MainActor public protocol SessionNotifying: AnyObject {
    func permission() async -> NotificationPermission
    func requestPermission() async throws -> Bool
    func send(identifier: String, title: String, body: String) async throws
}

/// UserNotifications is supplied by the macOS SDK. No permission is requested at initialization.
@MainActor public final class SessionNotifications: NSObject, SessionNotifying, UNUserNotificationCenterDelegate {
    public override init() { super.init() }
    private func center() -> UNUserNotificationCenter? {
        // The system notification service requires an app bundle, not swift test/CLI hosts.
        guard Bundle.main.bundleURL.pathExtension == "app", Bundle.main.bundleIdentifier != nil else { return nil }
        let value = UNUserNotificationCenter.current(); value.delegate = self
        return value
    }
    public func permission() async -> NotificationPermission {
        guard let center = center() else { return .unavailable }
        return await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                let permission: NotificationPermission
                switch settings.authorizationStatus {
                case .authorized, .provisional: permission = .allowed
                case .notDetermined: permission = .notRequested
                default: permission = .denied
                }
                continuation.resume(returning: permission)
            }
        }
    }
    public func requestPermission() async throws -> Bool {
        guard let center = center() else { return false }
        return try await withCheckedThrowingContinuation { continuation in
            center.requestAuthorization(options: [.alert]) { allowed, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: allowed) }
            }
        }
    }
    public func send(identifier: String, title: String, body: String) async throws {
        guard let center = center() else { return }
        let content = UNMutableNotificationContent()
        content.title = title; content.body = body; content.threadIdentifier = "cinder-sessions"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }
    nonisolated public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list])
    }
}

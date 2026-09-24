import Foundation
import CinderCore
import CinderPlatform

extension AppModel {
    func refreshNotificationPermission() async { notificationPermission = await notifications.permission() }
    func setNotificationsEnabled(_ enabled: Bool) async {
        guard !notificationBusy else { return }
        notificationBusy = true; notificationMessage = ""
        defer { notificationBusy = false }
        do {
            if enabled {
                await refreshNotificationPermission()
                if notificationPermission == .notRequested {
                    _ = try await notifications.requestPermission()
                    await refreshNotificationPermission()
                }
                guard notificationPermission == .allowed else {
                    notificationMessage = t("Allow Cinder in System Settings → Notifications to receive banners. Results remain in Session history.")
                    return
                }
            }
            try storage.saveNotificationPreferences(NotificationPreferences(enabled: enabled))
            notificationsEnabled = enabled
        } catch { notificationMessage = t("Notification settings could not be saved.") }
    }
    func deliverSessionNotification(_ record: SessionRecord) async {
        guard notificationsEnabled, [.completed, .deviceChanged, .failed, .missedSchedule].contains(record.outcome) else { return }
        let permission = await notifications.permission()
        notificationPermission = permission
        guard permission == .allowed, notificationsEnabled else { return }
        do {
            try await notifications.send(identifier: record.id.uuidString, title: "Cinder · " + t(record.outcome.label),
                body: record.outputName + " · " + t("Signal stages") + " " + Cycle.time(record.signalSeconds))
        } catch {
            notificationMessage = t("The notification could not be delivered. The result is saved in Session history.")
        }
    }
}

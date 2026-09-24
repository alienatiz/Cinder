import SwiftUI

struct NotificationSettingsView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        Panel(title: model.t("Notifications")) {
            Toggle(model.t("Notify when a plan finishes or needs attention"), isOn: Binding(
                get: { model.notificationsEnabled }, set: { value in Task { await model.setNotificationsEnabled(value) } }
            )).disabled(model.notificationBusy)
            Text(model.t("Silent banners for completion, playback failure, output changes and missed schedules. No notifications for routine pauses or each split session."))
                .foregroundStyle(.secondary)
            if model.notificationBusy { ProgressView() }
            if model.notificationPermission == .denied {
                Text(model.t("Allow Cinder in System Settings → Notifications to receive banners. Results remain in Session history."))
                    .foregroundStyle(.orange)
            } else if model.notificationPermission == .unavailable {
                Text(model.t("Notifications are available in the built Cinder app."))
            }
            if !model.notificationMessage.isEmpty { Text(model.notificationMessage).foregroundStyle(.orange) }
            Text(model.t("Session history works even when notifications are off or denied."))
            Button(model.t("Refresh permission status")) { Task { await model.refreshNotificationPermission() } }
        }.task { await model.refreshNotificationPermission() }
    }
}

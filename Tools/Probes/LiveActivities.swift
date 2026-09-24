// Compile-only probe. Never execute this code or include it in the app target.
import ActivityKit
import WidgetKit
import SwiftUI

struct SDKProbeAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var progress: Double
    }
    var sessionID: String
}

@MainActor
func probeActivityLifecycle() async throws {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    let content = ActivityContent(state: SDKProbeAttributes.ContentState(progress: 0), staleDate: nil)
    let activity = try Activity.request(
        attributes: SDKProbeAttributes(sessionID: "compile-only"), content: content, pushType: nil)
    await activity.update(content)
    await activity.end(content, dismissalPolicy: .immediate)
}

@MainActor
func probeActivityPresentation(
    content: @escaping (ActivityViewContext<SDKProbeAttributes>) -> Text,
    dynamicIsland: @escaping (ActivityViewContext<SDKProbeAttributes>) -> DynamicIsland
) -> ActivityConfiguration<SDKProbeAttributes> {
    // Closures avoid secondary result-builder errors from unavailable macOS UI.
    ActivityConfiguration(for: SDKProbeAttributes.self, content: content, dynamicIsland: dynamicIsland)
}

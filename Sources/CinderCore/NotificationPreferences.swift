import Foundation

public struct NotificationPreferences: Codable, Equatable, Sendable {
    public var enabled: Bool
    public init(enabled: Bool = false) { self.enabled = enabled }
}

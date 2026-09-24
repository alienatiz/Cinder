import Foundation

/// The preferred distribution channel is independent of the installed binary.
public enum UpdateChannel: String, Codable, CaseIterable, Sendable {
    case dev, stable

    public static var installedDefault: Self {
        Identity.releaseChannel == "stable" ? .stable : .dev
    }
}

public struct UpdatePreferences: Codable, Equatable, Sendable {
    public var channel: UpdateChannel

    public init(channel: UpdateChannel = .installedDefault) {
        self.channel = channel
    }
}

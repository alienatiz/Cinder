import Combine

/// Separate high-frequency presentation data from application/navigation state.
@MainActor public final class PlaybackDisplay: ObservableObject {
    @Published public private(set) var snapshot = AudioSnapshot()
    public init() {}
    public func update(_ value: AudioSnapshot) {
        guard value != snapshot else { return }
        snapshot = value
    }
}

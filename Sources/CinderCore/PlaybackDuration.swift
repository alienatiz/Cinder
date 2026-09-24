import Foundation

/// Minute-resolution duration shared by editing, persistence validation and display.
/// The existing `hours` JSON field stays compatible with older session/preset files.
public enum PlaybackDuration {
    public static let minimumMinutes = 1
    public static let maximumMinutes = 60_000

    public static func minutes(fromHours hours: Double) throws -> Int {
        let minutes = hours * 60
        guard minutes.isFinite,
              minutes >= Double(minimumMinutes) - 1e-7,
              minutes <= Double(maximumMinutes) + 1e-7,
              abs(minutes - minutes.rounded()) < 1e-7 else { throw CinderError.invalidDuration }
        return Int(minutes.rounded())
    }
    public static func hours(fromMinutes minutes: Int) throws -> Double {
        guard (minimumMinutes...maximumMinutes).contains(minutes) else { throw CinderError.invalidDuration }
        return Double(minutes) / 60
    }
    public static func dialSeconds(configuredSeconds: Double, elapsed: Double, state: PlaybackState) -> Double {
        state.locksSettings ? max(0, configuredSeconds - elapsed) : configuredSeconds
    }
}

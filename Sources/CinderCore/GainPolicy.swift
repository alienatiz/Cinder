import Foundation

/// Digital gain bounds, independent of manufacturer specifications or inferred SPL.
public enum GainPolicy {
    public static let minimum = -60.0
    public static let maximum = 0.0
    public static let initial = -30.0
    public static func display(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2))) + " dB"
    }
    public static func validate(_ value: Double) throws {
        guard value.isFinite, (minimum...maximum).contains(value) else { throw CinderError.invalidGain }
    }
}

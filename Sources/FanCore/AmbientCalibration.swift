import Foundation

/// The chassis-air sensor reads above the room. A user-entered room temperature turns that gap into a
/// fixed offset that is applied only for display; raw readings and history stay untouched.
public enum AmbientCalibration {
    /// Larger gaps are almost certainly a typo, not a real difference between the case and the room.
    public static let maxOffset: Double = 15

    /// Offset that makes `sensor` read as `room`, rounded to 0.1 °C and clamped to ±`maxOffset`.
    public static func offset(room: Double, sensor: Double) -> Double {
        let rounded = ((room - sensor) * 10).rounded() / 10
        // A tiny negative gap rounds to -0.0, which would print as "-0,0".
        if rounded == 0 { return 0 }
        return min(max(rounded, -maxOffset), maxOffset)
    }

    public static func apply(_ offset: Double, to value: Double?) -> Double? {
        value.map { $0 + offset }
    }
}

import Foundation

public struct FanLimits: Equatable {
    public var minRPM: Double
    public var maxRPM: Double
    public init(minRPM: Double, maxRPM: Double) {
        self.minRPM = minRPM
        self.maxRPM = maxRPM
    }
}

public enum FanDecision: Equatable {
    case auto
    case rpm([Double])   // one target per fan, already clamped to its limits
}

/// Pure control loop: temperature in, per-fan RPM targets out. Holds hysteresis and ramp state only.
public struct FanController {
    /// At or above this temperature the profile is ignored and fans go to maximum.
    /// 100 °C: M5 Pro P-cores sit at ~90 °C under ordinary load even with Apple's curve,
    /// so 90 °C would pin the fans at max during any build. Still below the throttling point.
    public static let hardLimitC = 100.0

    public var profile: Profile
    private var heldTemp: Double?
    private var lastRPM: [Double]?

    public init(profile: Profile) { self.profile = profile }

    public mutating func setProfile(_ p: Profile) {
        profile = p
        heldTemp = nil
        lastRPM = nil
    }

    public mutating func reset() {
        heldTemp = nil
        lastRPM = nil
    }

    /// - Parameters:
    ///   - temp: hottest relevant sensor, nil if sensors couldn't be read (→ auto).
    ///   - dt: seconds since the previous call.
    public mutating func decide(temp: Double?, fans: [FanLimits], dt: Double) -> FanDecision {
        guard let temp, !fans.isEmpty else { reset(); return .auto }

        let percent: Double
        switch profile.mode {
        case .auto:
            reset()
            return .auto
        case .fixed(let p):
            percent = p
        case .curve(let curve):
            if temp >= Self.hardLimitC {
                percent = 100
            } else {
                percent = curve.percent(at: effectiveTemp(temp))
            }
        }

        let hardLimit = temp >= Self.hardLimitC
        let desired = fans.map { $0.minRPM + (min(100, max(0, percent)) / 100) * ($0.maxRPM - $0.minRPM) }

        var next = desired
        if !hardLimit, let last = lastRPM, last.count == desired.count {
            next = zip(desired, last).map { want, prev in
                let step = (want > prev ? profile.rampUpRPMPerSec : profile.rampDownRPMPerSec) * max(dt, 0)
                return want > prev ? min(want, prev + step) : max(want, prev - step)
            }
        }
        next = zip(next, fans).map { min($1.maxRPM, max($1.minRPM, $0)) }
        lastRPM = next
        return .rpm(next)
    }

    /// Rises immediately, falls only once the sensor is more than `hysteresis` below the held value.
    private mutating func effectiveTemp(_ temp: Double) -> Double {
        guard let held = heldTemp else { heldTemp = temp; return temp }
        if temp >= held {
            heldTemp = temp
        } else if held - temp > profile.hysteresis {
            heldTemp = temp + profile.hysteresis
        }
        return heldTemp!
    }
}

import Foundation

/// Writes fan keys. Needs root. Always clamps to the fan's own [F*Mn, F*Mx].
public struct FanDriver {
    public let smc: SMC

    public init(smc: SMC) { self.smc = smc }

    public var fanCount: Int { Int((try? smc.read("FNum"))?.number ?? 0) }

    public func limits(fan: Int) -> FanLimits? {
        guard let mn = (try? smc.read("F\(fan)Mn"))?.number,
              let mx = (try? smc.read("F\(fan)Mx"))?.number, mx > mn else { return nil }
        return FanLimits(minRPM: mn, maxRPM: mx)
    }

    public var allLimits: [FanLimits] { (0..<fanCount).compactMap { limits(fan: $0) } }

    public func mode(fan: Int) -> Int? { (try? smc.read("F\(fan)Md"))?.number.map(Int.init) }

    /// Switches every fan to manual. Tries the plain write first; if macOS reverts it,
    /// raises the `Ftst` diagnostic flag (when the key exists) and retries for a few seconds.
    public func enableManual() throws {
        for fan in 0..<fanCount {
            if try forceMode(1, fan: fan, attempts: 3) { continue }
            try? smc.write("Ftst", bytes: [1])
            guard try forceMode(1, fan: fan, attempts: 50) else {
                throw SMCError.smcResult(0xFF, key: "F\(fan)Md (manual mode refused)")
            }
        }
    }

    public func setRPM(fan: Int, rpm: Double) throws {
        guard let lim = limits(fan: fan) else { return }
        let clamped = Float(min(lim.maxRPM, max(lim.minRPM, rpm)))
        try smc.write("F\(fan)Tg", bytes: SMCDecode.encodeFloat(clamped))
    }

    public func apply(_ decision: FanDecision) throws {
        switch decision {
        case .auto:
            restoreAuto()
        case .rpm(let targets):
            if (0..<fanCount).contains(where: { mode(fan: $0) != 1 }) { try enableManual() }
            for (fan, rpm) in targets.enumerated() { try setRPM(fan: fan, rpm: rpm) }
        }
    }

    /// Best-effort: never throws so it is safe in signal handlers and shutdown paths.
    public func restoreAuto() {
        for fan in 0..<fanCount { try? smc.write("F\(fan)Md", bytes: [0]) }
        try? smc.write("Ftst", bytes: [0])
    }

    private func forceMode(_ value: UInt8, fan: Int, attempts: Int) throws -> Bool {
        for _ in 0..<attempts {
            try? smc.write("F\(fan)Md", bytes: [value])
            if mode(fan: fan) == Int(value) { return true }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return false
    }
}

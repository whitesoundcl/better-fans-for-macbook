import Foundation

public struct FanReading: Codable, Equatable {
    public var index: Int
    public var actualRPM: Double
    public var targetRPM: Double
    public var minRPM: Double
    public var maxRPM: Double
    /// SMC mode: 1 = manual (something is overriding macOS), otherwise controlled by macOS.
    public var mode: Int
}

/// Discovers die temperature sensors (CPU P/E cores and GPU) once and reports the hottest.
public final class SensorReader {
    private let smc: SMC
    public private(set) var keys: [String]

    public init(smc: SMC) {
        self.smc = smc
        let prefixes = ["Tp", "Te", "Tg"]
        keys = ((try? smc.allKeys()) ?? []).filter { key in
            guard prefixes.contains(where: key.hasPrefix), let v = try? smc.read(key), v.type == "flt " else { return false }
            return Self.plausible(v.number)
        }
    }

    private static func plausible(_ t: Double?) -> Bool {
        guard let t else { return false }
        return t > 10 && t < 125
    }

    public func readings() -> [(key: String, celsius: Double)] {
        keys.compactMap { k in
            guard let t = (try? smc.read(k))?.number, Self.plausible(t) else { return nil }
            return (k, t)
        }
    }

    /// nil when no sensor could be read.
    public func hottest() -> Double? { readings().map(\.celsius).max() }

    private lazy var fanCount = Int((try? smc.read("FNum"))?.number ?? 0)
    private var fanRanges: [Int: (min: Double, max: Double)] = [:]

    public func fans() -> [FanReading] {
        (0..<fanCount).map { i in
            func v(_ s: String) -> Double { (try? smc.read("F\(i)\(s)"))?.number ?? 0 }
            // Min/max are fixed hardware limits: read once.
            if fanRanges[i] == nil { fanRanges[i] = (v("Mn"), v("Mx")) }
            let range = fanRanges[i]!
            return FanReading(index: i, actualRPM: v("Ac"), targetRPM: v("Tg"), minRPM: range.min, maxRPM: range.max, mode: Int(v("Md")))
        }
    }
}

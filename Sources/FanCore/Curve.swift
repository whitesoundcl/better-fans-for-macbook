import Foundation

public struct CurvePoint: Codable, Equatable {
    public var temp: Double      // °C
    public var percent: Double   // 0...100 of the fan's [min, max] range

    public init(temp: Double, percent: Double) {
        self.temp = temp
        self.percent = percent
    }
}

public struct Curve: Codable, Equatable {
    public private(set) var points: [CurvePoint]

    public init(points: [CurvePoint]) {
        self.points = points
            .map { CurvePoint(temp: $0.temp, percent: min(100, max(0, $0.percent))) }
            .sorted { $0.temp < $1.temp }
    }

    /// Linear interpolation, clamped to the first/last point outside the range.
    public func percent(at temp: Double) -> Double {
        guard let first = points.first, let last = points.last else { return 0 }
        if temp <= first.temp { return first.percent }
        if temp >= last.temp { return last.percent }
        for (a, b) in zip(points, points.dropFirst()) where temp <= b.temp {
            let span = b.temp - a.temp
            guard span > 0 else { return b.percent }
            return a.percent + (b.percent - a.percent) * (temp - a.temp) / span
        }
        return last.percent
    }
}

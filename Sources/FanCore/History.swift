import Foundation

/// One point of the temperature/fan timeline.
public struct HistorySample: Equatable, Identifiable {
    public let time: Date
    public let cpu: Double?
    public let gpu: Double?
    public let rpm: [Double]
    public var id: Date { time }

    public init(time: Date, cpu: Double?, gpu: Double?, rpm: [Double]) {
        self.time = time
        self.cpu = cpu
        self.gpu = gpu
        self.rpm = rpm
    }

    /// The value the fan curve reacts to.
    public var hottest: Double? { [cpu, gpu].compactMap { $0 }.max() }
}

public struct HistoryStats: Equatable {
    public let min: Double
    public let avg: Double
    public let max: Double
}

/// Time-bounded timeline of samples, oldest first. Pure value type so it can be unit-tested.
public struct TemperatureHistory {
    public let window: TimeInterval
    public private(set) var samples: [HistorySample] = []

    public init(window: TimeInterval) { self.window = window }

    /// Appends in time order (out-of-order samples are ignored) and drops anything older than `window`.
    public mutating func append(_ s: HistorySample) {
        if let last = samples.last, s.time <= last.time { return }
        samples.append(s)
        let cutoff = s.time.addingTimeInterval(-window)
        if let keep = samples.firstIndex(where: { $0.time >= cutoff }), keep > 0 {
            samples.removeFirst(keep)
        }
    }

    public func recent(_ span: TimeInterval, now: Date) -> ArraySlice<HistorySample> {
        let cutoff = now.addingTimeInterval(-span)
        let start = samples.firstIndex { $0.time >= cutoff } ?? samples.endIndex
        return samples[start...]
    }

    /// About `maxPoints` samples covering `span` (at most one more, for partial edge buckets).
    /// Buckets are fixed slots of absolute time, so as the window slides the interior points
    /// stay put instead of re-partitioning every sample (which makes a live chart shimmer).
    /// Each bucket keeps its peak temperatures (spikes stay visible) and its latest fan speeds.
    public func downsampled(_ span: TimeInterval, now: Date, maxPoints: Int) -> [HistorySample] {
        let slice = recent(span, now: now)
        guard maxPoints > 0, slice.count > maxPoints else { return Array(slice) }
        let width = span / Double(maxPoints)
        var result: [HistorySample] = []
        var chunk: [HistorySample] = []
        var slot: Int?
        func flush() {
            guard let last = chunk.last else { return }
            result.append(HistorySample(time: last.time,
                                        cpu: chunk.compactMap(\.cpu).max(),
                                        gpu: chunk.compactMap(\.gpu).max(),
                                        rpm: last.rpm))
            chunk.removeAll(keepingCapacity: true)
        }
        for s in slice {
            let k = Int((s.time.timeIntervalSinceReferenceDate / width).rounded(.down))
            if k != slot { flush(); slot = k }
            chunk.append(s)
        }
        flush()
        return result
    }

    public func stats(_ span: TimeInterval, now: Date, _ value: (HistorySample) -> Double?) -> HistoryStats? {
        let values = recent(span, now: now).compactMap(value)
        guard let lo = values.min(), let hi = values.max() else { return nil }
        return HistoryStats(min: lo, avg: values.reduce(0, +) / Double(values.count), max: hi)
    }

    /// Intervals between consecutive samples longer than `limit` (polling stalls).
    public func gaps(longerThan limit: TimeInterval) -> [(from: Date, to: Date)] {
        zip(samples, samples.dropFirst()).compactMap { a, b in
            b.time.timeIntervalSince(a.time) > limit ? (a.time, b.time) : nil
        }
    }
}

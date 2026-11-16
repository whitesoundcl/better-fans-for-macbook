import SwiftUI
import Charts
import FanCore

/// Hour:minute ticks; labels hang left of the tick so the rightmost one stays inside the chart.
var timeAxis: some AxisContent {
    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
        AxisGridLine()
        AxisTick()
        AxisValueLabel(format: .dateTime.hour().minute(), anchor: .topTrailing)
    }
}

/// Y range that fits the data with some headroom, snapped to 10 °C.
func temperatureDomain(_ samples: [HistorySample]) -> ClosedRange<Double> {
    let values = samples.flatMap { [$0.cpu, $0.gpu].compactMap { $0 } }
    guard let lo = values.min(), let hi = values.max() else { return 30...100 }
    let low = max(20, ((lo - 5) / 10).rounded(.down) * 10)
    let high = min(110, ((hi + 5) / 10).rounded(.up) * 10)
    return low...max(high, low + 20)
}

/// X range for a chart: the requested window, or the data's own extent.
func timeDomain(_ samples: [HistorySample], _ requested: ClosedRange<Date>?) -> ClosedRange<Date> {
    requested ?? (samples.first?.time ?? Date.now)...(samples.last?.time ?? Date.now)
}

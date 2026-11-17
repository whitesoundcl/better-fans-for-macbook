import SwiftUI
import Charts
import FanCore

/// Actual RPM per fan, on the hardware min–max scale.
struct FanChart: View {
    let samples: [HistorySample]
    let fans: [FanReading]
    var hover: HistorySample?
    var xDomain: ClosedRange<Date>?
    var onHover: ((Date?) -> Void)?

    /// With "Differentiate without color" every fan after the first gets a dashed line.
    @Environment(\.accessibilityDifferentiateWithoutColor) private var noColor

    var body: some View {
        let lo = fans.map(\.minRPM).min() ?? 0
        let hi = fans.map(\.maxRPM).max() ?? (samples.flatMap(\.rpm).max() ?? 1)
        let names = (0..<max(fans.count, samples.last?.rpm.count ?? 0)).map { "Ventilador \($0 + 1)" }
        Chart {
            ForEach(samples) { s in
                // Offset identity is fine here: position i *is* fan i.
                ForEach(Array(s.rpm.enumerated()), id: \.offset) { i, rpm in
                    let name = names[min(i, names.count - 1)]
                    LineMark(x: .value("Hora", s.time), y: .value("rpm", rpm), series: .value("Ventilador", name))
                        .foregroundStyle(by: .value("Ventilador", name))
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: noColor && i > 0 ? [6, 3] : []))
                }
            }
            if let h = hover { RuleMark(x: .value("Hora", h.time)).foregroundStyle(Color.secondary.opacity(0.5)) }
        }
        .chartForegroundStyleScale(domain: names, range: names.indices.map { Theme.fan($0) })
        .chartXScale(domain: timeDomain(samples, xDomain))
        .chartXAxis { timeAxis }
        .chartYScale(domain: lo...max(hi, lo + 1))
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { v in
                AxisGridLine()
                AxisValueLabel { if let d = v.as(Double.self) { Text("\(Int(d).formatted())") } }
            }
        }
        .chartOverlay { proxy in
            if let onHover { ChartHoverLayer(proxy: proxy, onHover: onHover) }
        }
    }
}

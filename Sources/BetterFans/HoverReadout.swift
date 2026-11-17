import SwiftUI
import FanCore

/// Values of the sample under the pointer, shown in the temperature card's title row.
struct HoverReadout: View {
    let sample: HistorySample?

    var body: some View {
        if let s = sample {
            let rpm = s.rpm.map { Theme.rpm($0) }.formatted(.list(type: .and))
            Text("\(s.time, format: .dateTime.hour().minute().second()) · CPU \(Theme.celsius(s.cpu, decimals: 1)) · GPU \(Theme.celsius(s.gpu, decimals: 1))\(rpm.isEmpty ? "" : " · \(rpm)")")
                .font(.caption).monospacedDigit().foregroundStyle(.secondary)
        }
    }
}

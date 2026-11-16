import SwiftUI
import FanCore

/// Fan speed as a bar between its hardware min and max. One VoiceOver element with the share of range in use.
struct FanBar: View {
    let fan: FanReading

    private var fraction: Double {
        guard fan.maxRPM > fan.minRPM else { return 0 }
        return min(1, max(0, (fan.actualRPM - fan.minRPM) / (fan.maxRPM - fan.minRPM)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("Ventilador \(fan.index + 1)", systemImage: "fanblades")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(Theme.rpm(fan.actualRPM)).font(.caption.weight(.medium)).monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule().fill(Theme.fan(fan.index).gradient)
                        .frame(width: max(6, geo.size.width * fraction))
                }
            }
            .frame(height: 6)
        }
        .help("Mín. \(Theme.rpm(fan.minRPM)) · máx. \(Theme.rpm(fan.maxRPM)) · objetivo \(Theme.rpm(fan.targetRPM))")
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(Int((fraction * 100).rounded())) % de su rango")
    }
}

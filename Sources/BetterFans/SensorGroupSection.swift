import SwiftUI
import FanCore

/// One sensor group in the "Sensores" window: header with count/max/average, then a grid of readings.
struct SensorGroupSection: View {
    let group: SensorGroup

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(group.name).font(.subheadline.weight(.semibold))
                Text("\(group.items.count) · máx \(Theme.celsius(group.max, decimals: 1)) · prom \(Theme.celsius(group.average, decimals: 1))")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
                ForEach(group.items) { s in
                    let drivesCurve = AllSensorsReader.drivesCurve(s.key)
                    HStack(spacing: 4) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(Color.accentColor)
                            .opacity(drivesCurve ? 1 : 0)
                        Text(s.key).font(.system(.caption, design: .monospaced))
                        Spacer(minLength: 4)
                        Text(Theme.celsius(s.celsius, decimals: 1))
                            .font(.caption).monospacedDigit().foregroundStyle(Theme.temp(s.celsius))
                    }
                    // One VoiceOver stop per sensor instead of marker + key + value.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(s.key)
                    .accessibilityValue(Theme.celsius(s.celsius, decimals: 1))
                    .accessibilityHint(drivesCurve ? "Lo usa la curva de ventiladores" : "")
                }
            }
        }
    }
}

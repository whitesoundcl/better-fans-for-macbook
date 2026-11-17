import SwiftUI
import FanCore

/// Last 10 minutes of CPU temperature in the menu. The only menu view that observes the history,
/// so a new sample redraws this card rather than the whole menu.
struct SparklineCard: View {
    @EnvironmentObject var store: HistoryStore
    let open: () -> Void

    private let span: TimeInterval = 600

    var body: some View {
        let now = store.history.samples.last?.time ?? Date.now
        let samples = store.history.downsampled(span, now: now, maxPoints: 120)
        let peak = store.history.stats(span, now: now) { $0.cpu }?.max
        Button(action: open) {
            VStack(alignment: .leading, spacing: 4) {
                TemperatureChart(samples: samples, compact: true)
                    .frame(height: 46)
                    .opacity(samples.count >= 2 ? 1 : 0)
                    .overlay {
                        Text("Reuniendo datos…").font(.caption).foregroundStyle(.secondary)
                            .opacity(samples.count >= 2 ? 0 : 1)
                            // opacity alone keeps it in the accessibility tree
                            .accessibilityHidden(samples.count >= 2)
                    }
                HStack {
                    Text("CPU · últimos 10 min").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if let peak {
                        Text("máx \(Int(peak.rounded()))°").font(.caption).monospacedDigit().foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
            .padding(8)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Abrir el monitor")
        .accessibilityHint("Abre el monitor con el historial completo")
    }
}

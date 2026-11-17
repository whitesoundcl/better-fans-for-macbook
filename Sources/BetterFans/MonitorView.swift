import SwiftUI
import FanCore

/// "Monitor" window: current readings, then temperature and fan-speed history for the chosen range.
struct MonitorView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var store: HistoryStore
    @StateObject private var state = MonitorState()

    var body: some View {
        let now = store.history.samples.last?.time ?? Date.now
        let window = now.addingTimeInterval(-state.span)...now
        let samples = store.history.downsampled(state.span, now: now, maxPoints: 360)
        let cpuStats = store.history.stats(state.span, now: now) { $0.cpu }
        let gpuStats = store.history.stats(state.span, now: now) { $0.gpu }
        let hovered = state.hover.flatMap { h in samples.first { $0.time == h } }
        let onHover: (Date?) -> Void = { state.hover(at: $0, in: samples) }

        VStack(alignment: .leading, spacing: 14) {
            MonitorHeader(state: state)
            HStack(spacing: 10) {
                StatTile(title: "CPU ahora", value: Theme.celsius(model.cpuTemp), detail: summary(cpuStats), tint: Theme.temp(model.cpuTemp))
                StatTile(title: "GPU ahora", value: Theme.celsius(model.gpuTemp), detail: summary(gpuStats), tint: Theme.temp(model.gpuTemp))
                AmbientCalibrationButton {
                    StatTile(title: model.ambientOffset == 0 ? "Ambiente" : "Ambiente · ajustado",
                             value: Theme.celsius(model.ambientDisplay, decimals: 1),
                             detail: summary(store.history.stats(state.span, now: now) { AmbientCalibration.apply(model.ambientOffset, to: $0.ambient) }),
                             tint: Theme.temp(model.ambientDisplay))
                }
                .disabled(model.ambientTemp == nil)
                StatTile(title: "Ventiladores", value: averageRPM, detail: model.fans.isEmpty ? nil : "promedio de \(model.fans.count)")
                StatTile(title: "Perfil", value: model.selected.name,
                         detail: model.targetPercent.map { "pide \(Int($0.rounded())) % ahora" } ?? "macOS decide")
            }
            ChartCard(title: "Temperatura") {
                HoverReadout(sample: hovered)
            } content: {
                TemperatureChart(samples: samples, hover: hovered, xDomain: window, onHover: onHover)
                    .frame(minHeight: 220)
            }
            ChartCard(title: "Velocidad de ventiladores") {
                EmptyView()
            } content: {
                FanChart(samples: samples, fans: model.fans, hover: hovered, xDomain: window, onHover: onHover)
                    .frame(minHeight: 130)
            }
            Text("Reuniendo datos… el gráfico se llena con una muestra cada \(Int(AppModel.pollInterval)) s mientras la app está abierta.")
                .font(.caption).foregroundStyle(.secondary)
                .opacity(samples.count < 3 ? 1 : 0)
                .accessibilityHidden(samples.count >= 3)  // opacity alone keeps it in the tree
        }
        .padding(18)
        .frame(minWidth: 680, minHeight: 560)
    }

    private var averageRPM: String {
        guard !model.fans.isEmpty else { return "–" }
        return Theme.rpm(model.fans.map(\.actualRPM).reduce(0, +) / Double(model.fans.count))
    }

    private func summary(_ s: HistoryStats?) -> String? {
        s.map { "prom \(Int($0.avg.rounded()))° · máx \(Int($0.max.rounded()))°" }
    }
}

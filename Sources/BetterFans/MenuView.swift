import SwiftUI
import FanCore

struct MenuView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            SparklineCard { open("monitor") }
            VStack(spacing: 8) {
                ForEach(model.fans, id: \.index) { FanBar(fan: $0) }
            }
            notices
            Divider()
            VStack(alignment: .leading, spacing: 2) {
                Text("Perfil").font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.leading, 4)
                ForEach(model.profiles) { ProfileRow(profile: $0) }
            }
            Divider()
            HStack(spacing: 8) {
                shortcut("Monitor", "chart.line.uptrend.xyaxis", window: "monitor")
                shortcut("Sensores", "thermometer.medium", window: "sensors")
                shortcut("Curvas", "slider.horizontal.3", window: "editor")
            }
            HStack {
                Toggle("Abrir al iniciar sesión", isOn: $model.launchAtLoginSetting)
                    .toggleStyle(.switch).controlSize(.mini).font(.caption)
                Spacer()
                Button("Salir", action: quit)
                    .keyboardShortcut("q")
                    .controlSize(.small)
            }
        }
        .padding(14)
        .frame(width: 320)
    }

    // MARK: Sections

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            reading("CPU", model.cpuTemp, size: 34)
            reading("GPU", model.gpuTemp, size: 22)
            Spacer()
            let s = model.status
            StatusPill(text: s.text, systemImage: s.icon, tint: s.tint)
        }
    }

    private func reading(_ label: String, _ t: Double?, size: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(t.map { "\($0.formatted(.number.precision(.fractionLength(0))))°" } ?? "–")
                .font(.system(size: size, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.temp(t))
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var notices: some View {
        if model.otherAppControlling {
            Label("Otra app está controlando los ventiladores: ciérrala para que no compitan.", systemImage: "exclamationmark.triangle.fill")
                .font(.caption).foregroundStyle(.orange)
        }
        if let detail = model.status.detail {
            Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        if let error = model.saveError {
            Label(error, systemImage: "exclamationmark.circle")
                .font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
        }
        if let error = model.loginItemError {
            Label(error, systemImage: "exclamationmark.circle")
                .font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func shortcut(_ title: String, _ icon: String, window: String) -> some View {
        Button { open(window) } label: {
            Label(title, systemImage: icon)
                .labelStyle(VerticalLabelStyle())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Actions

    private func open(_ id: String) {
        if #available(macOS 14, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        openWindow(id: id)
    }

    private func quit() {
        model.flushSave()
        model.resetToAuto()
        NSApp.terminate(nil)
    }
}

import SwiftUI
import AppKit
import FanCore

struct MenuView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(model.temperature.map { String(format: "%.0f °C", $0) } ?? "– °C")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    ForEach(model.fans, id: \.index) { f in
                        Text("Ventilador \(f.index + 1): \(Int(f.actualRPM)) rpm")
                            .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            }

            Picker("Perfil", selection: $model.selectedName) {
                ForEach(model.profiles) { Text($0.name).tag($0.name) }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()

            ProfilePreview(profile: model.selected, currentTemp: model.temperature)

            statusLine

            if model.otherAppControlling {
                Label("Otra app está controlando los ventiladores: ciérrala para que no compita.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange)
            }

            Divider()
            Button("Ver todos los sensores…") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "sensors")
            }
            Button("Editar curva…") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "editor")
            }
            Toggle("Abrir al iniciar sesión", isOn: Binding(get: { model.launchAtLogin }, set: model.setLaunchAtLogin))
            Button("Salir") {
                model.resetToAuto()
                NSApp.terminate(nil)
            }
        }
        .padding(14)
        .frame(width: 290)
        .onAppear { model.menuOpen = true }
        .onDisappear { model.menuOpen = false }
    }

    @ViewBuilder private var statusLine: some View {
        if !model.helperReachable {
            Label("Helper no instalado o detenido (control de Apple activo).", systemImage: "bolt.slash")
                .font(.caption).foregroundStyle(.secondary)
        } else if let err = model.helperStatus?.lastError {
            Label(err, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.red)
        } else if model.helperStatus?.controlling == true {
            Label("Curva activa", systemImage: "fanblades.fill").font(.caption).foregroundStyle(.green)
        } else {
            Label("Control de Apple", systemImage: "fanblades").font(.caption).foregroundStyle(.secondary)
        }
    }
}

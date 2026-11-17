import SwiftUI

/// Title, helper status and range picker at the top of the monitor.
struct MonitorHeader: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var state: MonitorState

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Monitor").font(.title2.weight(.semibold))
                Text("Historial de la última hora; se pierde al cerrar la app.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            let s = model.status
            StatusPill(text: s.text, systemImage: s.icon, tint: s.tint)
            Picker("Rango", selection: $state.span) {
                ForEach(MonitorState.spans, id: \.seconds) { Text($0.label).tag($0.seconds) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 260)
        }
    }
}

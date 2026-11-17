import SwiftUI

/// Makes an ambient reading clickable: opens the calibration popover anchored to it.
struct AmbientCalibrationButton<Label: View>: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var state = AmbientCalibrationState()
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button { state.open(showing: model.ambientDisplay) } label: {
            label().contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(Theme.ambientHelp(offset: model.ambientOffset))
        .accessibilityHint("Abre la calibración de la temperatura ambiente")
        .popover(isPresented: $state.isPresented, arrowEdge: .bottom) {
            AmbientCalibrationView(state: state).environmentObject(model)
        }
    }
}

import SwiftUI
import FanCore

/// Turns a thermometer reading into the offset applied to the chassis-air sensor.
struct AmbientCalibrationView: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var state: AmbientCalibrationState

    var body: some View {
        let sensor = model.ambientForCalibration
        VStack(alignment: .leading, spacing: 12) {
            Text("Calibrar temperatura ambiente").font(.headline)
            Text("Mide la sala con un termómetro y escribe el valor. Hazlo con el Mac en reposo y sin cargar: con carga el aire de adentro sube y el ajuste deja de calzar.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    label("Sensor TAOL")
                        .help("Promedio de los últimos 2 minutos")
                    value(Theme.celsius(sensor, decimals: 1))
                }
                GridRow {
                    label("Sala (termómetro)")
                    HStack(spacing: 4) {
                        TextField("Temperatura de la sala", value: $state.room, format: .number.precision(.fractionLength(0...1)))
                            .labelsHidden()
                            .multilineTextAlignment(.trailing)
                            .frame(width: 52)
                        Text("°C")
                        Stepper("Temperatura de la sala", value: $state.room, in: 0...45, step: 0.5)
                            .labelsHidden()
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                if let sensor {
                    GridRow {
                        label("Ajuste")
                        value(Theme.signedCelsius(AmbientCalibration.offset(room: state.room, sensor: sensor)))
                    }
                }
            }
            HStack {
                Button("Quitar ajuste") {
                    model.ambientOffset = 0
                    state.isPresented = false
                }
                .disabled(model.ambientOffset == 0)
                Spacer()
                Button("Calibrar") {
                    model.calibrateAmbient(room: state.room)
                    state.isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(sensor == nil)
            }
        }
        .padding(14)
        .frame(width: 300)
    }

    private func label(_ text: String) -> some View {
        Text(text).fixedSize()
    }

    private func value(_ text: String) -> some View {
        Text(text).monospacedDigit().frame(maxWidth: .infinity, alignment: .trailing)
    }
}

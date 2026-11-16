import SwiftUI

/// Hysteresis and ramp steppers for the selected curve profile, bound live to the model.
struct CurveSettings: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            GridRow {
                Stepper(value: $model.selectedHysteresis, in: 0...10) {
                    Text("Histéresis: **\(Int(model.selectedHysteresis)) °C**")
                }
                Text("Baja la velocidad solo cuando la temperatura cae más que esto.").font(.caption).foregroundStyle(.secondary)
            }
            GridRow {
                Stepper(value: $model.selectedRampUp, in: 100...4000, step: 100) {
                    Text("Subida: **\(Int(model.selectedRampUp).formatted()) rpm/s**")
                }
                Text("Qué tan rápido acelera.").font(.caption).foregroundStyle(.secondary)
            }
            GridRow {
                Stepper(value: $model.selectedRampDown, in: 50...2000, step: 50) {
                    Text("Bajada: **\(Int(model.selectedRampDown).formatted()) rpm/s**")
                }
                Text("Más lento = menos cambios de ruido.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .font(.callout)
    }
}

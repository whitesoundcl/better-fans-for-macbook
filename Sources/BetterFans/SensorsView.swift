import SwiftUI

/// "Sensores" window: every SMC temperature sensor, grouped, filterable and refreshed while open.
struct SensorsView: View {
    @StateObject private var model = SensorsModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if !model.loaded {
                ProgressView("Leyendo sensores…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(model.groups) { SensorGroupSection(group: $0) }
                    }
                    .padding(.bottom, 8)
                }
                .overlay {
                    Text("Ningún sensor coincide con «\(model.filter)».")
                        .foregroundStyle(.secondary)
                        .opacity(model.groups.isEmpty ? 1 : 0)
                        .accessibilityHidden(!model.groups.isEmpty)
                }
            }
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 420)
        .task { await model.run() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let hottest = model.hottest {
                Text("\(model.values.count) sensores · más caliente: \(hottest.key) \(Theme.celsius(hottest.celsius, decimals: 1))")
                    .font(.headline)
            }
            HStack {
                TextField("Filtrar (ej. Tp, GPU, Tm0)", text: $model.filter)
                    .textFieldStyle(.roundedBorder)
                Picker("Orden", selection: $model.sortByTemp) {
                    Text("Por temperatura").tag(true)
                    Text("Por nombre").tag(false)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 230)
            }
            Label {
                Text("Sensor que usa la curva de ventiladores. Las claves sin etiqueta no están documentadas por Apple.")
            } icon: {
                Image(systemName: "circle.fill").font(.system(size: 6)).foregroundStyle(Color.accentColor)
            }
            .font(.caption).foregroundStyle(.secondary)
        }
    }
}

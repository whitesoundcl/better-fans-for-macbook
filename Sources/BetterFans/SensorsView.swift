import SwiftUI
import FanCore

/// Owns its own SMC connection and a serial queue so the ~300 reads never touch the main thread.
final class SensorsBackend {
    private let queue = DispatchQueue(label: "betterfans.sensors")
    private var reader: AllSensorsReader?

    func fetch(_ done: @escaping ([SensorValue]) -> Void) {
        queue.async {
            if self.reader == nil, let smc = try? SMC() { self.reader = AllSensorsReader(smc: smc) }
            let values = self.reader?.read() ?? []
            DispatchQueue.main.async { done(values) }
        }
    }
}

@MainActor
final class SensorsModel: ObservableObject {
    @Published var values: [SensorValue] = []
    @Published var loaded = false
    @Published var filter = ""
    @Published var sortByTemp = true

    private let backend = SensorsBackend()
    private var timer: Timer?

    /// Polls only while the window is visible.
    func start() {
        guard timer == nil else { return }
        refresh()
        let t = Timer(timeInterval: 2, repeats: true) { [weak self] _ in Task { @MainActor in self?.refresh() } }
        t.tolerance = 0.5
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func refresh() {
        backend.fetch { [weak self] v in
            self?.values = v
            self?.loaded = true
        }
    }

    var groups: [(name: String, items: [SensorValue])] {
        let q = filter.trimmingCharacters(in: .whitespaces).lowercased()
        let shown = q.isEmpty ? values : values.filter {
            $0.key.lowercased().contains(q) || AllSensorsReader.group(for: $0.key).lowercased().contains(q)
        }
        let order = ["CPU", "CPU (eficiencia)", "GPU", "Batería"]
        return Dictionary(grouping: shown) { AllSensorsReader.group(for: $0.key) }
            .map { name, items in
                (name, sortByTemp ? items.sorted { $0.celsius > $1.celsius } : items.sorted { $0.key < $1.key })
            }
            .sorted { a, b in
                let ia = order.firstIndex(of: a.name) ?? order.count, ib = order.firstIndex(of: b.name) ?? order.count
                return ia != ib ? ia < ib : a.name < b.name
            }
    }
}

struct SensorsView: View {
    @StateObject private var model = SensorsModel()

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if !model.loaded {
                ProgressView("Leyendo sensores…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(model.groups, id: \.name) { group in
                            section(group.name, group.items)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 420)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let hottest = model.values.max(by: { $0.celsius < $1.celsius }) {
                Text("\(model.values.count) sensores · más caliente: \(hottest.key) \(format(hottest.celsius))")
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
            Text("● = sensor que usa la curva de ventiladores. Las claves sin etiqueta no están documentadas por Apple.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func section(_ name: String, _ items: [SensorValue]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(name).font(.subheadline.weight(.semibold))
                Text("\(items.count) · máx \(format(items.map(\.celsius).max() ?? 0)) · prom \(format(items.map(\.celsius).reduce(0, +) / Double(max(items.count, 1))))")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
                ForEach(items) { s in
                    HStack(spacing: 4) {
                        Text(AllSensorsReader.drivesCurve(s.key) ? "●" : " ")
                            .font(.caption2).foregroundStyle(Color.accentColor)
                        Text(s.key).font(.system(.caption, design: .monospaced))
                        Spacer(minLength: 4)
                        Text(format(s.celsius)).font(.caption).monospacedDigit().foregroundStyle(color(s.celsius))
                    }
                }
            }
        }
    }

    private func format(_ t: Double) -> String { String(format: "%.1f °C", t) }

    private func color(_ t: Double) -> Color {
        switch t {
        case ..<60: return .green
        case ..<80: return .primary
        case ..<90: return .orange
        default:    return .red
        }
    }
}

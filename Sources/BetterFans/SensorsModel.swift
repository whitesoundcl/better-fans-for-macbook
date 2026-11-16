import Foundation
import FanCore

/// State of the "Sensores" window. Groups are recomputed when data, filter or sort order change,
/// not on every redraw.
@MainActor
final class SensorsModel: ObservableObject {
    @Published private(set) var values: [SensorValue] = []
    @Published private(set) var groups: [SensorGroup] = []
    @Published private(set) var hottest: SensorValue?
    @Published private(set) var loaded = false
    @Published var filter = "" { didSet { regroup() } }
    @Published var sortByTemp = true { didSet { regroup() } }

    private let backend = SensorsBackend()
    private static let order = ["CPU", "CPU (eficiencia)", "GPU", "Batería"]

    /// Refreshes every 2 s while the window is open; the view's `task()` cancels it on close.
    func run() async {
        while !Task.isCancelled {
            values = await backend.read()
            hottest = values.max { $0.celsius < $1.celsius }
            loaded = true
            regroup()
            try? await Task.sleep(for: .seconds(2))
        }
    }

    private func regroup() {
        let q = filter.trimmingCharacters(in: .whitespaces)
        let shown = q.isEmpty ? values : values.filter {
            $0.key.localizedStandardContains(q) || AllSensorsReader.group(for: $0.key).localizedStandardContains(q)
        }
        groups = Dictionary(grouping: shown) { AllSensorsReader.group(for: $0.key) }
            .map { name, items in
                SensorGroup(name: name, items: sortByTemp ? items.sorted { $0.celsius > $1.celsius } : items.sorted { $0.key < $1.key })
            }
            .sorted { a, b in
                let ia = Self.order.firstIndex(of: a.name) ?? Self.order.count
                let ib = Self.order.firstIndex(of: b.name) ?? Self.order.count
                return ia != ib ? ia < ib : a.name < b.name
            }
    }
}

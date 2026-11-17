import FanCore

/// Sensors sharing a prefix group, with their summary computed once (not on every redraw).
struct SensorGroup: Identifiable {
    let name: String
    let items: [SensorValue]
    let max: Double
    let average: Double
    var id: String { name }

    init(name: String, items: [SensorValue]) {
        self.name = name
        self.items = items
        let temps = items.map(\.celsius)
        max = temps.max() ?? 0
        average = temps.isEmpty ? 0 : temps.reduce(0, +) / Double(temps.count)
    }
}

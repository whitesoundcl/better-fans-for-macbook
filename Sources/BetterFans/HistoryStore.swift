import Foundation
import FanCore

/// Timeline kept apart from `AppModel` so a new sample only redraws the charts.
@MainActor
final class HistoryStore: ObservableObject {
    /// One hour at the 2 s poll rate is ~1800 samples.
    @Published private(set) var history = TemperatureHistory(window: 3600)

    func append(_ s: HistorySample) { history.append(s) }
}

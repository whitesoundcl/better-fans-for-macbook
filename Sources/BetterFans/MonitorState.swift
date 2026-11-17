import Foundation
import FanCore

/// View state for the monitor window (kept out of @State: no SwiftUI macros with the Command Line Tools).
@MainActor
final class MonitorState: ObservableObject {
    @Published var span: TimeInterval = 15 * 60
    /// Time of the sample under the pointer, snapped to an existing sample.
    @Published private(set) var hover: Date?

    static let spans: [(label: String, seconds: TimeInterval)] = [("5 min", 300), ("15 min", 900), ("30 min", 1800), ("1 h", 3600)]

    /// Snaps the pointer to the nearest sample and publishes only when that sample changes,
    /// so moving the mouse doesn't redraw the window on every pixel.
    func hover(at date: Date?, in samples: [HistorySample]) {
        let snapped = date.flatMap { d in
            samples.min { abs($0.time.timeIntervalSince(d)) < abs($1.time.timeIntervalSince(d)) }?.time
        }
        if snapped != hover { hover = snapped }
    }
}

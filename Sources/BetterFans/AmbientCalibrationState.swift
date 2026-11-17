import Foundation

/// Popover state for calibrating the ambient reading (an object because the Command Line Tools
/// can't expand `@State`).
@MainActor
final class AmbientCalibrationState: ObservableObject {
    @Published var isPresented = false
    /// Room temperature the user reads off a thermometer.
    @Published var room: Double = 22

    /// Starts from what the app shows now, rounded to the stepper's 0.5 °C.
    func open(showing current: Double?) {
        if let current { room = (current * 2).rounded() / 2 }
        isPresented = true
    }
}

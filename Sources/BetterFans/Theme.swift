import SwiftUI
import FanCore

/// Shared look: one temperature colour scale and the app's number formats.
enum Theme {
    static let cpu = Color(red: 0.96, green: 0.45, blue: 0.20)
    static let gpu = Color(red: 0.30, green: 0.55, blue: 0.98)
    static let fanColors: [Color] = [Color(red: 0.20, green: 0.72, blue: 0.62), Color(red: 0.62, green: 0.44, blue: 0.92)]

    static func fan(_ i: Int) -> Color { fanColors[i % fanColors.count] }

    /// System yellow is unreadable as text on a light background; use a darker amber in light mode.
    private static let warm = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? .systemYellow
            : NSColor(red: 0.70, green: 0.52, blue: 0.0, alpha: 1)
    })

    /// Same thresholds everywhere: calm < 60, warm < 80, hot < 90, critical above.
    static func temp(_ t: Double?) -> Color {
        guard let t else { return .secondary }
        return switch t {
        case ..<60: .green
        case ..<80: warm
        case ..<90: .orange
        default: .red
        }
    }

    /// Locale-aware, e.g. "84,6 °C" in Spanish (`String(format:)` would always use a period,
    /// which reads as a thousands separator next to "3.912 rpm").
    static func celsius(_ t: Double?, decimals: Int = 0) -> String {
        guard let t else { return "–" }
        return "\(t.formatted(.number.precision(.fractionLength(decimals)))) °C"
    }

    static func rpm(_ v: Double) -> String { "\(Int(v.rounded()).formatted()) rpm" }

    static func icon(for p: Profile) -> String {
        switch p.mode {
        case .auto: "apple.logo"
        case .fixed: "gauge.high"
        case .curve: "chart.xyaxis.line"
        }
    }

    static let card = Color.primary.opacity(0.05)
}

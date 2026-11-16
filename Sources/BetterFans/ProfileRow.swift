import SwiftUI
import FanCore

/// Selectable profile with what it would do at the current temperature. Used in the menu and the editor.
struct ProfileRow: View {
    @EnvironmentObject var model: AppModel
    let profile: Profile

    private var isSelected: Bool { model.selectedName == profile.name }

    private var subtitle: String {
        var s = switch profile.mode {
        case .auto: "Curva de macOS"
        case .fixed(let p): "Fija al \(Int(p.rounded())) %"
        case .curve:
            if let t = model.temperature, let pct = profile.percent(at: t) {
                "A \(Int(t.rounded()))° → \(Int(pct.rounded())) %"
            } else {
                "Curva según temperatura"
            }
        }
        if model.isModifiedBuiltIn(profile) { s += " · editado" }
        return s
    }

    var body: some View {
        Button(action: select) {
            HStack(spacing: 10) {
                Image(systemName: Theme.icon(for: profile))
                    .frame(width: 18)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(profile.name).font(.callout)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
                    .opacity(isSelected ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 6).padding(.vertical, 5)
            .background(isSelected ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func select() { model.selectedName = profile.name }
}

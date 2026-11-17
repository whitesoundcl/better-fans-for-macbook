import SwiftUI
import FanCore

/// Shown in the editor for automatic or fixed-speed profiles, which have no curve to edit.
struct NotCurvePanel: View {
    let profile: Profile
    let createCurve: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(profile.mode == .auto
                 ? "Con este perfil macOS controla los ventiladores con su curva original."
                 : "Este perfil mantiene una velocidad fija y no usa curva.")
            // `Button(_:systemImage:action:)` needs macOS 14.
            Button(action: createCurve) { Label("Crear una curva editable", systemImage: "plus") }
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .center)
        .padding()
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
    }
}

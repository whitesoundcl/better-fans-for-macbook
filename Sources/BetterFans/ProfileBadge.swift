import SwiftUI
import FanCore

/// "Integrado", "Integrado · editado" or "Personalizado" next to the profile name in the editor.
struct ProfileBadge: View {
    @EnvironmentObject var model: AppModel
    let profile: Profile

    var body: some View {
        let builtIn = model.isBuiltIn(profile.name)
        let (text, tint): (String, Color) = builtIn
            ? (model.isModifiedBuiltIn(profile) ? ("Integrado · editado", .orange) : ("Integrado", .secondary))
            : ("Personalizado", .accentColor)
        StatusPill(text: text, systemImage: builtIn ? "lock" : "person", tint: tint)
    }
}

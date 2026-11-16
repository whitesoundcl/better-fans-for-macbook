import SwiftUI
import FanCore

/// "Curvas" window: profile list on the left, the selected profile's curve and settings on the right.
struct EditorView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var state = EditorState()

    var body: some View {
        let profile = model.selected
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: Theme.icon(for: profile))
                        .font(.title2).foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                    Text(profile.name).font(.title2.weight(.semibold))
                    ProfileBadge(profile: profile)
                    Spacer()
                    if model.isModifiedBuiltIn(profile) {
                        Button("Restablecer", action: restore)
                            .help("Vuelve a los valores originales de este perfil")
                    } else if !model.isBuiltIn(profile.name) {
                        Button("Eliminar", role: .destructive, action: askDelete)
                            .confirmationDialog("¿Eliminar «\(profile.name)»?", isPresented: $state.confirmDelete) {
                                Button("Eliminar", role: .destructive, action: deleteSelected)
                            } message: {
                                Text("Se borra este perfil personalizado y vuelve a usarse «\(Profile.apple.name)».")
                            }
                    }
                }

                if profile.isCurve {
                    curveSection(profile)
                    CurveSettings()
                } else {
                    NotCurvePanel(profile: profile, createCurve: createCurve)
                }

                if let error = model.saveError {
                    Label(error, systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.red)
                }
                Spacer(minLength: 0)
                // Only curves are copied here; other profiles use "Crear una curva editable" above.
                VStack(alignment: .leading, spacing: 10) {
                    Divider()
                    HStack {
                        TextField("Nombre para una copia…", text: $state.newName)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(duplicate)
                        Button("Duplicar perfil", action: duplicate)
                            .disabled(state.newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .opacity(profile.isCurve ? 1 : 0)
                .disabled(!profile.isCurve)
                .accessibilityHidden(!profile.isCurve)
            }
            .padding(20)
        }
        .frame(minWidth: 780, minHeight: 520)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Perfiles").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                .padding(.horizontal, 10).padding(.bottom, 4)
            ForEach(model.profiles) { ProfileRow(profile: $0) }
            Spacer()
            Text("El perfil que elijas aquí queda activo.")
                .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 6)
        }
        .padding(12)
        .frame(width: 230)
    }

    private func curveSection(_ profile: Profile) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            CurveEditor(points: $model.selectedCurvePoints, currentTemp: model.temperature)
                .frame(minHeight: 280)
                .padding(8)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
            HStack(spacing: 14) {
                Label("Arrastra los puntos", systemImage: "hand.draw")
                Label("Doble clic añade uno", systemImage: "plus.circle")
                Label("Clic derecho lo elimina", systemImage: "minus.circle")
                Spacer()
                if let pct = profile.percent(at: model.temperature), let fan = model.fans.first {
                    Text("Ahora: \(Int(pct.rounded())) % ≈ \(Theme.rpm(fan.minRPM + pct / 100 * (fan.maxRPM - fan.minRPM)))")
                        .monospacedDigit()
                }
            }
            .font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: Actions

    private func restore() { model.delete(model.selected.name) }

    private func askDelete() { state.confirmDelete = true }

    private func deleteSelected() { model.delete(model.selected.name) }

    private func createCurve() { model.duplicate(Profile.legsCool, as: "Mi curva") }

    private func duplicate() {
        guard model.selected.isCurve else { return }
        model.duplicate(model.selected, as: state.newName)
        state.newName = ""
    }
}

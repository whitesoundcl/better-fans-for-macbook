import SwiftUI

/// Icon above title, for the menu's window shortcuts. Keeps a real `Label` so VoiceOver reads the title, not the symbol name.
struct VerticalLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 3) {
            configuration.icon.font(.title3)
            configuration.title.font(.caption)
        }
    }
}

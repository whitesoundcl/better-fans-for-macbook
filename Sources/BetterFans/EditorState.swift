import Foundation

/// Editor window state (no @State: the Command Line Tools lack the SwiftUI macro plugin).
@MainActor
final class EditorState: ObservableObject {
    @Published var newName = ""
    @Published var confirmDelete = false
}

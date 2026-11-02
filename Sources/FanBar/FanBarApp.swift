import SwiftUI
import AppKit

@main
struct FanBarApp: App {
    @StateObject private var model = AppModel()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuView().environmentObject(model)
        } label: {
            Text(model.menuBarTitle)
        }
        .menuBarExtraStyle(.window)

        Window("Editor de curva", id: "editor") {
            EditorView().environmentObject(model)
        }
        .windowResizability(.contentSize)
    }
}

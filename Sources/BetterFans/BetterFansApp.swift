import SwiftUI
import AppKit

@main
struct BetterFansApp: App {
    @StateObject private var model: AppModel

    init() {
        // `BetterFans --snapshot <dir>` renders every window with sample data to PNGs and exits.
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count {
            Snapshot.run(to: URL(fileURLWithPath: args[i + 1]))
            exit(0)
        }
        NSApplication.shared.setActivationPolicy(.accessory)
        _model = StateObject(wrappedValue: AppModel())
    }

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(model)
                .environmentObject(model.history)
        } label: {
            Label(model.menuBarTitle, systemImage: "fanblades.fill")
                .labelStyle(.titleAndIcon)
                .monospacedDigit()
                .accessibilityLabel("Better Fans, \(model.menuBarTitle)")
        }
        .menuBarExtraStyle(.window)

        Window("Monitor", id: "monitor") {
            MonitorView()
                .environmentObject(model)
                .environmentObject(model.history)
        }
        .defaultSize(width: 780, height: 640)

        Window("Curvas", id: "editor") {
            EditorView().environmentObject(model)
        }
        .defaultSize(width: 840, height: 620)

        Window("Sensores", id: "sensors") {
            SensorsView()
        }
        .defaultSize(width: 620, height: 680)
    }
}

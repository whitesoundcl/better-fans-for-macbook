import SwiftUI
import AppKit
import FanCore

/// Renders the app's views with `AppModel.preview()` to PNGs (light and dark), for reviewing the UI
/// without opening the menu bar or granting accessibility access. Run: `BetterFans --snapshot <dir>`.
@MainActor
enum Snapshot {
    static func run(to dir: URL) {
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            FileHandle.standardError.write(Data("snapshot: no se pudo crear \(dir.path): \(error)\n".utf8))
            return
        }
        let quiet = AppModel.preview()
        let apple = AppModel.preview(selected: Profile.apple.name)
        let offline = AppModel.preview(selected: Profile.apple.name, helper: false)
        func menu(_ m: AppModel) -> AnyView { AnyView(MenuView().environmentObject(m).environmentObject(m.history)) }
        func monitor(_ m: AppModel) -> AnyView { AnyView(MonitorView().environmentObject(m).environmentObject(m.history)) }
        let views: [(name: String, view: AnyView, size: CGSize)] = [
            ("menu", menu(quiet), CGSize(width: 320, height: 0)),
            ("menu-apple", menu(apple), CGSize(width: 320, height: 0)),
            ("menu-nohelper", menu(offline), CGSize(width: 320, height: 0)),
            ("monitor", monitor(quiet), CGSize(width: 780, height: 640)),
            ("monitor-apple", monitor(apple), CGSize(width: 780, height: 640)),
            ("editor", AnyView(EditorView().environmentObject(quiet)), CGSize(width: 840, height: 620)),
            ("editor-apple", AnyView(EditorView().environmentObject(apple)), CGSize(width: 840, height: 620)),
            ("sensors", AnyView(SensorsView()), CGSize(width: 620, height: 680)),
        ]
        for v in views {
            for dark in [false, true] {
                let url = dir.appendingPathComponent("\(v.name)-\(dark ? "dark" : "light").png")
                do {
                    try render(v.view, size: v.size, dark: dark, to: url)
                    print(url.path)
                } catch {
                    FileHandle.standardError.write(Data("snapshot \(url.lastPathComponent): \(error)\n".utf8))
                }
            }
        }
    }

    /// Height 0 means "fit the content".
    private static func render(_ view: AnyView, size: CGSize, dark: Bool, to url: URL) throws {
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        let root = view
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, dark ? .dark : .light)
        let host = NSHostingView(rootView: root)
        host.appearance = appearance
        var target = size
        if target.height == 0 {
            host.frame = NSRect(x: 0, y: 0, width: size.width, height: 2000)
            target.height = host.fittingSize.height
        }
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: target), styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = appearance
        window.contentView = host
        host.frame = NSRect(origin: .zero, size: target)
        // Let SwiftUI and Charts finish layout and their first animation pass.
        RunLoop.current.run(until: Date().addingTimeInterval(1.0))
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw CocoaError(.fileWriteUnknown) }
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        try png.write(to: url)
    }
}

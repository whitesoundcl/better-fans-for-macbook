import SwiftUI
import AppKit

/// The menu-bar window can open taller than the menu and then centres it, leaving transparent bands
/// above and below the background (they look white over a light app). This keeps the window's
/// height equal to the menu's, with its top edge pinned under the menu bar.
struct MenuWindowFitter: NSViewRepresentable {
    let height: CGFloat

    func makeNSView(context: Context) -> FitterView { FitterView() }

    func updateNSView(_ view: FitterView, context: Context) {
        view.height = height
    }

    final class FitterView: NSView {
        var height: CGFloat = 0 {
            didSet { if height != oldValue { scheduleFit() } }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            scheduleFit()
        }

        /// After the current layout pass, so SwiftUI isn't resizing the window at the same time.
        private func scheduleFit() {
            DispatchQueue.main.async { [weak self] in self?.fit() }
        }

        private func fit() {
            guard let window, height > 0, abs(window.frame.height - height) > 0.5 else { return }
            var frame = window.frame
            frame.origin.y += frame.height - height
            frame.size.height = height
            window.setFrame(frame, display: true)
        }
    }
}

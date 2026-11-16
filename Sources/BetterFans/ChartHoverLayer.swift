import SwiftUI
import Charts

/// Transparent layer over a chart's plot that reports the date under the pointer (nil when it leaves).
struct ChartHoverLayer: View {
    let proxy: ChartProxy
    let onHover: (Date?) -> Void

    var body: some View {
        GeometryReader { geo in
            Rectangle().fill(.clear).contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let loc):
                        onHover(proxy.value(atX: loc.x - plotOriginX(geo), as: Date.self))
                    case .ended:
                        onHover(nil)
                    }
                }
        }
    }

    /// `plotAreaFrame` is soft-deprecated from macOS 14 in favour of the optional `plotFrame`.
    private func plotOriginX(_ geo: GeometryProxy) -> CGFloat {
        if #available(macOS 14, *) {
            guard let frame = proxy.plotFrame else { return 0 }
            return geo[frame].origin.x
        }
        return geo[proxy.plotAreaFrame].origin.x
    }
}

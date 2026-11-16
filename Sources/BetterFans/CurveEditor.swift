import SwiftUI
import FanCore

/// Draggable temperature→percent graph. Double-click empty space adds a point; right-click a point removes it.
/// With VoiceOver each point is an adjustable element (swipe up/down changes its speed by 5 %).
struct CurveEditor: View {
    @Binding var points: [CurvePoint]
    var currentTemp: Double?
    var editable = true

    /// Goes past the hard limit so the "always max" zone is visible.
    private let tempRange: ClosedRange<Double> = 30...105
    private let inset = EdgeInsets(top: 10, leading: 36, bottom: 22, trailing: 10)
    private static let whole = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0))

    var body: some View {
        GeometryReader { geo in
            let plot = CGSize(width: geo.size.width - inset.leading - inset.trailing,
                              height: geo.size.height - inset.top - inset.bottom)
            ZStack(alignment: .topLeading) {
                axes(plot)
                ZStack {
                    limitZone(plot)
                    areaPath(plot).fill(.linearGradient(colors: [Color.accentColor.opacity(0.28), Color.accentColor.opacity(0.03)],
                                                        startPoint: .top, endPoint: .bottom))
                    curvePath(plot).stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
                    nowMarker(plot)
                    // Index identity: CurvePoint has no stable id yet (it would change the saved JSON).
                    ForEach(editable ? Array(points.indices) : [], id: \.self) { i in
                        handle(i, plot)
                    }
                }
                .frame(width: plot.width, height: plot.height)
                .coordinateSpace(name: "plot")  // `.coordinateSpace(.named(_:))` needs macOS 14
                .contentShape(Rectangle())
                .onTapGesture(count: 2, coordinateSpace: .named("plot")) { loc in addPoint(at: loc, plot) }
                .offset(x: inset.leading, y: inset.top)
            }
        }
    }

    // MARK: Editing (each change is a single write to `points`)

    private func addPoint(at loc: CGPoint, _ size: CGSize) {
        guard editable else { return }
        let new = CurvePoint(temp: min(temp(at: loc.x, size.width).rounded(), FanController.hardLimitC - 1),
                             percent: percent(at: loc.y, size.height).rounded())
        points = (points + [new]).sorted { $0.temp < $1.temp }
    }

    private func drag(_ i: Int, to loc: CGPoint, size: CGSize) {
        let lower = i > 0 ? points[i - 1].temp + 1 : tempRange.lowerBound
        let upper = i < points.count - 1 ? points[i + 1].temp - 1 : FanController.hardLimitC
        var p = points[i]
        p.temp = min(max(temp(at: loc.x, size.width).rounded(), lower), upper)
        p.percent = min(max(percent(at: loc.y, size.height).rounded(), 0), 100)
        points[i] = p
    }

    private func nudge(_ i: Int, _ direction: AccessibilityAdjustmentDirection) {
        var p = points[i]
        p.percent = min(100, max(0, p.percent + (direction == .increment ? 5 : -5)))
        points[i] = p
    }

    private func remove(_ i: Int) {
        guard points.count > 2 else { return }
        points.remove(at: i)
    }

    // MARK: Pieces

    private func handle(_ i: Int, _ size: CGSize) -> some View {
        let pt = points[i]
        let summary = "\(pt.temp.formatted(Self.whole)) °C → \(pt.percent.formatted(Self.whole)) %"
        return Circle().fill(Color.accentColor).frame(width: 14, height: 14)
            .overlay { Circle().stroke(.white, lineWidth: 2) }
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            .position(x: x(pt.temp, size.width), y: y(pt.percent, size.height))
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("plot")).onChanged { g in
                drag(i, to: g.location, size: size)
            })
            .contextMenu {
                Button("Eliminar punto", role: .destructive) { remove(i) }
                    .disabled(points.count <= 2)
            }
            .help(summary)
            .accessibilityElement()
            .accessibilityLabel("Punto \(i + 1) de la curva")
            .accessibilityValue("\(pt.temp.formatted(Self.whole)) grados, \(pt.percent.formatted(Self.whole)) por ciento")
            .accessibilityAdjustableAction { nudge(i, $0) }
            .accessibilityAction(named: "Eliminar punto") { remove(i) }
    }

    private func axes(_ plot: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            Path { p in
                for t in stride(from: 40.0, through: 100, by: 10) {
                    p.move(to: CGPoint(x: x(t, plot.width), y: 0)); p.addLine(to: CGPoint(x: x(t, plot.width), y: plot.height))
                }
                for pc in stride(from: 0.0, through: 100, by: 25) {
                    p.move(to: CGPoint(x: 0, y: y(pc, plot.height))); p.addLine(to: CGPoint(x: plot.width, y: y(pc, plot.height)))
                }
            }
            .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
            .offset(x: inset.leading, y: inset.top)
            ForEach(Array(stride(from: 40, through: 100, by: 10)), id: \.self) { t in
                Text("\(t)°").font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                    .position(x: inset.leading + x(Double(t), plot.width), y: inset.top + plot.height + 11)
            }
            ForEach([0, 50, 100], id: \.self) { pc in
                Text("\(pc)%").font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                    .position(x: inset.leading / 2, y: inset.top + y(Double(pc), plot.height))
            }
        }
        .accessibilityHidden(true)
    }

    private func limitZone(_ size: CGSize) -> some View {
        let x0 = x(FanController.hardLimitC, size.width)
        return Rectangle().fill(Color.red.opacity(0.10))
            .frame(width: size.width - x0, height: size.height)
            .position(x: x0 + (size.width - x0) / 2, y: size.height / 2)
            .help("Desde \(Int(FanController.hardLimitC)) °C los ventiladores van al máximo, sin importar la curva.")
    }

    @ViewBuilder private func nowMarker(_ size: CGSize) -> some View {
        if let t = currentTemp, tempRange.contains(t) {
            let pct = t >= FanController.hardLimitC ? 100 : Curve(points: points).percent(at: t)
            Path { p in
                p.move(to: CGPoint(x: x(t, size.width), y: 0)); p.addLine(to: CGPoint(x: x(t, size.width), y: size.height))
            }
            .stroke(Theme.temp(t), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            Circle().fill(Theme.temp(t)).frame(width: 8, height: 8)
                .position(x: x(t, size.width), y: y(pct, size.height))
            if editable {
                Text("\(t, format: Self.whole)° → \(pct, format: Self.whole) %")
                    .font(.caption2.weight(.medium)).monospacedDigit()
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(.regularMaterial, in: Capsule())
                    .position(x: min(max(x(t, size.width), 40), size.width - 40), y: 10)
                    .accessibilityLabel("Ahora \(t.formatted(Self.whole)) grados, \(pct.formatted(Self.whole)) por ciento")
            }
        }
    }

    private func curvePath(_ size: CGSize) -> Path {
        Path { p in
            let c = Curve(points: points)
            p.move(to: CGPoint(x: 0, y: y(c.percent(at: tempRange.lowerBound), size.height)))
            for pt in c.points { p.addLine(to: CGPoint(x: x(pt.temp, size.width), y: y(pt.percent, size.height))) }
            p.addLine(to: CGPoint(x: size.width, y: y(c.percent(at: tempRange.upperBound), size.height)))
        }
    }

    private func areaPath(_ size: CGSize) -> Path {
        var p = curvePath(size)
        p.addLine(to: CGPoint(x: size.width, y: size.height))
        p.addLine(to: CGPoint(x: 0, y: size.height))
        p.closeSubpath()
        return p
    }

    private func x(_ t: Double, _ w: CGFloat) -> CGFloat { CGFloat((t - tempRange.lowerBound) / (tempRange.upperBound - tempRange.lowerBound)) * w }
    private func y(_ pc: Double, _ h: CGFloat) -> CGFloat { h - CGFloat(pc / 100) * h }
    private func temp(at x: CGFloat, _ w: CGFloat) -> Double { tempRange.lowerBound + Double(x / w) * (tempRange.upperBound - tempRange.lowerBound) }
    private func percent(at y: CGFloat, _ h: CGFloat) -> Double { Double((h - y) / h) * 100 }
}

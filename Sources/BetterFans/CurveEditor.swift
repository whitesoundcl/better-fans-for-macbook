import SwiftUI
import FanCore

/// Draggable temperature→percent graph. Double-click empty space adds a point; right-click a point removes it.
struct CurveEditor: View {
    @Binding var points: [CurvePoint]
    var currentTemp: Double?
    var editable = true

    private let tempRange: ClosedRange<Double> = 30...100

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                grid(size)
                curvePath(size).stroke(Color.accentColor, lineWidth: 2)
                if let t = currentTemp, tempRange.contains(t) {
                    Rectangle().fill(Color.red.opacity(0.5)).frame(width: 1)
                        .position(x: x(t, size.width), y: size.height / 2)
                }
                ForEach(editable ? Array(points.indices) : [], id: \.self) { i in
                    Circle().fill(Color.accentColor).frame(width: 14, height: 14)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .position(x: x(points[i].temp, size.width), y: y(points[i].percent, size.height))
                        .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("plot")).onChanged { g in
                            drag(i, to: g.location, size: size)
                        })
                        .contextMenu {
                            Button("Eliminar punto") { if points.count > 2 { points.remove(at: i) } }
                        }
                        .help(String(format: "%.0f °C → %.0f %%", points[i].temp, points[i].percent))
                }
            }
            .coordinateSpace(name: "plot")
            .allowsHitTesting(editable)
            .contentShape(Rectangle())
            .onTapGesture(count: 2, coordinateSpace: .named("plot")) { loc in
                points.append(CurvePoint(temp: temp(at: loc.x, size.width).rounded(),
                                         percent: percent(at: loc.y, size.height).rounded()))
                points.sort { $0.temp < $1.temp }
            }
        }
    }

    private func drag(_ i: Int, to loc: CGPoint, size: CGSize) {
        let lower = i > 0 ? points[i - 1].temp + 1 : tempRange.lowerBound
        let upper = i < points.count - 1 ? points[i + 1].temp - 1 : tempRange.upperBound
        points[i].temp = min(max(temp(at: loc.x, size.width).rounded(), lower), upper)
        points[i].percent = min(max(percent(at: loc.y, size.height).rounded(), 0), 100)
    }

    private func grid(_ size: CGSize) -> some View {
        ZStack {
            Path { p in
                for t in stride(from: 40.0, through: 100, by: 10) {
                    p.move(to: CGPoint(x: x(t, size.width), y: 0)); p.addLine(to: CGPoint(x: x(t, size.width), y: size.height))
                }
                for pc in stride(from: 0.0, through: 100, by: 25) {
                    p.move(to: CGPoint(x: 0, y: y(pc, size.height))); p.addLine(to: CGPoint(x: size.width, y: y(pc, size.height)))
                }
            }.stroke(Color.secondary.opacity(0.25), lineWidth: 0.5)
            ForEach(Array(stride(from: 40, through: 100, by: 10)), id: \.self) { t in
                Text("\(t)°").font(.caption2).foregroundStyle(.secondary)
                    .position(x: x(Double(t), size.width), y: size.height - 6)
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

    private func x(_ t: Double, _ w: CGFloat) -> CGFloat { CGFloat((t - tempRange.lowerBound) / (tempRange.upperBound - tempRange.lowerBound)) * w }
    private func y(_ pc: Double, _ h: CGFloat) -> CGFloat { h - CGFloat(pc / 100) * h }
    private func temp(at x: CGFloat, _ w: CGFloat) -> Double { tempRange.lowerBound + Double(x / w) * (tempRange.upperBound - tempRange.lowerBound) }
    private func percent(at y: CGFloat, _ h: CGFloat) -> Double { Double((h - y) / h) * 100 }
}

/// Read-only view of a profile's behaviour, shown in the menu for the clicked profile.
struct ProfilePreview: View {
    let profile: Profile
    var currentTemp: Double?

    var body: some View {
        switch profile.mode {
        case .auto:
            Text("macOS controla los ventiladores con su curva original.")
                .font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        case .fixed(let percent):
            chart([CurvePoint(temp: 30, percent: percent), CurvePoint(temp: 100, percent: percent)],
                  caption: "Velocidad fija: \(Int(percent)) %")
        case .curve(let curve):
            chart(curve.points, caption: "Temperatura (°C) → velocidad (%)")
        }
    }

    private func chart(_ points: [CurvePoint], caption: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            CurveEditor(points: .constant(points), currentTemp: currentTemp, editable: false)
                .frame(height: 110)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            Text(caption).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

/// Local workaround: CommandLineTools on macOS 27 lack the SwiftUIMacros plugin needed by @State.
final class NameBox: ObservableObject { @Published var value = "" }

struct EditorView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var nameBox = NameBox()
    private var newName: String { get { nameBox.value } nonmutating set { nameBox.value = newValue } }

    var body: some View {
        let profile = model.selected
        VStack(alignment: .leading, spacing: 12) {
            Text("Perfil: \(profile.name)").font(.headline)
            if case .curve(let curve) = profile.mode {
                CurveEditor(points: Binding(
                    get: { curve.points },
                    set: { var p = profile; p.mode = .curve(Curve(points: $0)); model.update(p) }
                ), currentTemp: model.temperature)
                .frame(width: 480, height: 280)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                Text("Eje X: temperatura máx. CPU/GPU · Eje Y: % entre RPM mínimo y máximo de cada ventilador. Doble clic añade un punto; clic derecho lo elimina.")
                    .font(.caption).foregroundStyle(.secondary).frame(width: 480, alignment: .leading)
                HStack {
                    Stepper("Histéresis: \(Int(profile.hysteresis)) °C", value: Binding(
                        get: { profile.hysteresis }, set: { var p = profile; p.hysteresis = $0; model.update(p) }), in: 0...10)
                }
            } else {
                Text("Este perfil no usa una curva. Selecciona «Frío para piernas» o «Silencioso» en el menú, o crea una copia editable:")
                    .frame(width: 480, alignment: .leading)
            }
            HStack {
                TextField("Guardar como nuevo perfil…", text: $nameBox.value)
                Button("Duplicar") {
                    guard !newName.isEmpty else { return }
                    var p = profile.isCurve ? profile : Profile.legsCool
                    p.name = newName
                    model.update(p)
                    model.selectedName = newName
                    newName = ""
                }
            }.frame(width: 480)
        }
        .padding(20)
    }
}

private extension Profile {
    var isCurve: Bool { if case .curve = mode { return true } else { return false } }
}

import SwiftUI

/// A simple top-down vector mouse, drawn in code (no vendor artwork).
struct MouseShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        p.move(to: CGPoint(x: r.minX + w * 0.5, y: r.minY))
        p.addCurve(to: CGPoint(x: r.minX + w * 0.98, y: r.minY + h * 0.38),
                   control1: CGPoint(x: r.minX + w * 0.82, y: r.minY),
                   control2: CGPoint(x: r.minX + w * 0.98, y: r.minY + h * 0.14))
        p.addCurve(to: CGPoint(x: r.minX + w * 0.5, y: r.maxY),
                   control1: CGPoint(x: r.minX + w * 0.98, y: r.minY + h * 0.78),
                   control2: CGPoint(x: r.minX + w * 0.8, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.minX + w * 0.02, y: r.minY + h * 0.38),
                   control1: CGPoint(x: r.minX + w * 0.2, y: r.maxY),
                   control2: CGPoint(x: r.minX + w * 0.02, y: r.minY + h * 0.78))
        p.addCurve(to: CGPoint(x: r.minX + w * 0.5, y: r.minY),
                   control1: CGPoint(x: r.minX + w * 0.02, y: r.minY + h * 0.14),
                   control2: CGPoint(x: r.minX + w * 0.18, y: r.minY))
        return p
    }
}

struct MouseDiagram: View {
    var selected: Int?
    var labels: [Int: String] = [:]
    var onTap: ((PhysicalButton) -> Void)?

    var body: some View {
        GeometryReader { geo in
            let size = CGSize(width: min(geo.size.width, geo.size.height * 0.62), height: min(geo.size.height, geo.size.width / 0.62))
            let origin = CGPoint(x: (geo.size.width - size.width) / 2, y: (geo.size.height - size.height) / 2)
            ZStack(alignment: .topLeading) {
                ZStack {
                    MouseShape().fill(.quinary)
                    MouseShape().stroke(.tertiary, lineWidth: 1)
                    // Button split and wheel.
                    Path { p in
                        p.move(to: CGPoint(x: size.width * 0.5, y: 0))
                        p.addLine(to: CGPoint(x: size.width * 0.5, y: size.height * 0.38))
                    }.stroke(.quaternary, lineWidth: 1)
                    Capsule().fill(.tertiary)
                        .frame(width: size.width * 0.08, height: size.height * 0.11)
                        .position(x: size.width * 0.5, y: size.height * 0.16)
                }
                .frame(width: size.width, height: size.height)
                .offset(x: origin.x, y: origin.y)

                ForEach(PhysicalButton.mt760) { b in
                    let pt = CGPoint(x: origin.x + b.anchor.x * size.width, y: origin.y + b.anchor.y * size.height)
                    Button { onTap?(b) } label: {
                        Circle()
                            .fill(selected == b.id ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
                            .frame(width: selected == b.id ? 12 : 8, height: selected == b.id ? 12 : 8)
                            .frame(width: 32, height: 32)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .focusEffectDisabled()
                    .help(b.name)
                    .position(pt)
                    .animation(.bouncy, value: selected)
                }
            }
        }
    }
}

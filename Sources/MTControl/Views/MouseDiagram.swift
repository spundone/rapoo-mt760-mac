import SwiftUI

// Original vector artwork of a right-handed ergonomic mouse in the MT760's layout.
// Coordinates are normalised to a 0.62 : 1 (width : height) box.

/// Outer body: narrow nose, flared thumb rest on the left, broad palm.
struct MouseBodyShape: Shape {
    func path(in r: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height) }
        var path = Path()
        path.move(to: p(0.52, 0.02))
        path.addCurve(to: p(0.86, 0.12), control1: p(0.70, 0.00), control2: p(0.82, 0.05))
        path.addCurve(to: p(0.92, 0.55), control1: p(0.93, 0.24), control2: p(0.95, 0.42))
        path.addCurve(to: p(0.70, 0.98), control1: p(0.90, 0.78), control2: p(0.83, 0.95))
        path.addCurve(to: p(0.22, 0.96), control1: p(0.55, 1.01), control2: p(0.35, 1.00))
        path.addCurve(to: p(0.02, 0.70), control1: p(0.09, 0.92), control2: p(0.00, 0.83))
        path.addCurve(to: p(0.10, 0.40), control1: p(0.04, 0.57), control2: p(0.12, 0.49))
        path.addCurve(to: p(0.20, 0.10), control1: p(0.08, 0.30), control2: p(0.10, 0.16))
        path.addCurve(to: p(0.52, 0.02), control1: p(0.30, 0.04), control2: p(0.40, 0.02))
        path.closeSubpath()
        return path
    }
}

/// Seams between the two main buttons and the palm.
struct MouseSeams: Shape {
    func path(in r: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height) }
        var path = Path()
        // centre split, interrupted by the wheel well
        path.move(to: p(0.525, 0.025)); path.addLine(to: p(0.525, 0.085))
        path.move(to: p(0.527, 0.265)); path.addLine(to: p(0.53, 0.42))
        // back edge of the buttons
        path.move(to: p(0.11, 0.43))
        path.addCurve(to: p(0.915, 0.45), control1: p(0.35, 0.49), control2: p(0.70, 0.50))
        return path
    }
}

/// Parts of the mouse, keyed by firmware key ID.
enum MousePart: Int, CaseIterable {
    case left = 0, middle = 1, right = 2, dpi = 4, forward = 5, back = 6, thumbWheel = 7

    var anchor: CGPoint {
        switch self {
        case .left: CGPoint(x: 0.32, y: 0.22)
        case .right: CGPoint(x: 0.73, y: 0.22)
        case .middle: CGPoint(x: 0.525, y: 0.175)
        case .dpi: CGPoint(x: 0.525, y: 0.33)
        case .forward: CGPoint(x: 0.115, y: 0.515)
        case .back: CGPoint(x: 0.09, y: 0.625)
        case .thumbWheel: CGPoint(x: 0.13, y: 0.39)
        }
    }

    /// Callout column and vertical slot (0…1 of the drawing height).
    var callout: (leftSide: Bool, y: CGFloat) {
        switch self {
        case .left: (true, 0.16)
        case .thumbWheel: (true, 0.36)
        case .forward: (true, 0.52)
        case .back: (true, 0.66)
        case .middle: (false, 0.10)
        case .right: (false, 0.24)
        case .dpi: (false, 0.38)
        }
    }

    var name: String {
        switch self {
        case .left: "Left button"
        case .right: "Right button"
        case .middle: "Wheel"
        case .dpi: "Top button"
        case .forward: "Forward"
        case .back: "Back"
        case .thumbWheel: "Thumb wheel"
        }
    }
}

/// The illustration itself, without callouts.
struct MouseArt: View {
    var highlighted: MousePart?
    var ledColor: Color = .accentColor
    @Environment(\.colorScheme) private var scheme

    private var bodyTop: Color { scheme == .dark ? Color(white: 0.30) : Color(white: 0.97) }
    private var bodyBottom: Color { scheme == .dark ? Color(white: 0.13) : Color(white: 0.80) }
    private var seam: Color { scheme == .dark ? .black.opacity(0.55) : .black.opacity(0.16) }
    private var rubber: Color { scheme == .dark ? Color(white: 0.08) : Color(white: 0.22) }

    var body: some View {
        GeometryReader { g in
            let r = CGRect(origin: .zero, size: g.size)
            ZStack {
                // soft contact shadow
                MouseBodyShape()
                    .fill(.black.opacity(scheme == .dark ? 0.55 : 0.18))
                    .blur(radius: r.width * 0.05)
                    .offset(y: r.height * 0.025)
                    .scaleEffect(0.97)

                // body with top-left lighting
                MouseBodyShape()
                    .fill(LinearGradient(colors: [bodyTop, bodyBottom], startPoint: .topLeading, endPoint: .bottomTrailing))
                MouseBodyShape()
                    .fill(RadialGradient(colors: [.white.opacity(scheme == .dark ? 0.12 : 0.55), .clear],
                                         center: UnitPoint(x: 0.45, y: 0.62), startRadius: 0, endRadius: r.width * 0.5))
                MouseBodyShape()
                    .stroke(LinearGradient(colors: [.white.opacity(scheme == .dark ? 0.25 : 0.9), .black.opacity(0.25)],
                                           startPoint: .top, endPoint: .bottom), lineWidth: 1)

                // thumb rest groove
                Path { p in
                    p.move(to: CGPoint(x: 0.06 * r.width, y: 0.74 * r.height))
                    p.addCurve(to: CGPoint(x: 0.30 * r.width, y: 0.90 * r.height),
                               control1: CGPoint(x: 0.09 * r.width, y: 0.84 * r.height),
                               control2: CGPoint(x: 0.18 * r.width, y: 0.89 * r.height))
                }
                .stroke(seam, style: StrokeStyle(lineWidth: 1, lineCap: .round))

                MouseSeams().stroke(seam, style: StrokeStyle(lineWidth: 1.2, lineCap: .round))

                // wheel well and wheel
                Capsule().fill(rubber.opacity(0.9))
                    .frame(width: r.width * 0.095, height: r.height * 0.19)
                    .position(x: 0.525 * r.width, y: 0.175 * r.height)
                WheelView(highlighted: highlighted == .middle)
                    .frame(width: r.width * 0.06, height: r.height * 0.16)
                    .position(x: 0.525 * r.width, y: 0.175 * r.height)

                // DPI button with stage light
                RoundedRectangle(cornerRadius: r.width * 0.02)
                    .fill(LinearGradient(colors: [bodyTop.opacity(0.9), bodyBottom], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: r.width * 0.02).stroke(seam, lineWidth: 1))
                    .frame(width: r.width * 0.075, height: r.height * 0.05)
                    .position(x: 0.525 * r.width, y: 0.33 * r.height)
                Circle().fill(ledColor)
                    .frame(width: r.width * 0.022)
                    .shadow(color: ledColor.opacity(0.9), radius: r.width * 0.025)
                    .position(x: 0.525 * r.width, y: 0.385 * r.height)

                // thumb wheel (horizontal scroll)
                Capsule().fill(rubber)
                    .frame(width: r.width * 0.05, height: r.height * 0.075)
                    .overlay(
                        VStack(spacing: r.height * 0.008) {
                            ForEach(0..<5, id: \.self) { _ in Rectangle().fill(.white.opacity(0.12)).frame(height: 1) }
                        }
                        .padding(.vertical, r.height * 0.008).padding(.horizontal, 2)
                    )
                    .rotationEffect(.degrees(-8))
                    .position(x: 0.13 * r.width, y: 0.39 * r.height)

                // side buttons along the thumb edge
                sideButton(r).rotationEffect(.degrees(12)).position(x: 0.12 * r.width, y: 0.515 * r.height)
                sideButton(r).rotationEffect(.degrees(18)).position(x: 0.095 * r.width, y: 0.625 * r.height)

                // glow on the selected part
                if let h = highlighted {
                    Circle()
                        .fill(Color.accentColor.opacity(0.35))
                        .frame(width: r.width * 0.16)
                        .blur(radius: r.width * 0.03)
                        .position(x: h.anchor.x * r.width, y: h.anchor.y * r.height)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
        }
        .aspectRatio(0.62, contentMode: .fit)
        .animation(.smooth(duration: 0.25), value: highlighted)
    }

    private func sideButton(_ r: CGRect) -> some View {
        RoundedRectangle(cornerRadius: r.width * 0.03)
            .fill(LinearGradient(colors: [bodyTop, bodyBottom], startPoint: .leading, endPoint: .trailing))
            .overlay(RoundedRectangle(cornerRadius: r.width * 0.03).stroke(seam, lineWidth: 1))
            .frame(width: r.width * 0.07, height: r.height * 0.085)
    }
}

private struct WheelView: View {
    var highlighted: Bool
    var body: some View {
        GeometryReader { g in
            ZStack {
                Capsule().fill(LinearGradient(colors: [Color(white: 0.35), Color(white: 0.12)], startPoint: .leading, endPoint: .trailing))
                VStack(spacing: g.size.height * 0.07) {
                    ForEach(0..<8, id: \.self) { _ in Rectangle().fill(.white.opacity(0.16)).frame(height: 1) }
                }
                .padding(.vertical, g.size.height * 0.08)
                .padding(.horizontal, g.size.width * 0.12)
                if highlighted { Capsule().stroke(Color.accentColor, lineWidth: 1.5) }
            }
        }
    }
}

/// The illustration plus Options+-style callouts with leader lines.
struct MouseDiagram: View {
    var selected: Int?
    /// Firmware key ID → callout text. Parts without text get no callout.
    var labels: [Int: String] = [:]
    var ledColor: Color = .accentColor
    var onTap: ((PhysicalButton) -> Void)?

    var body: some View {
        GeometryReader { g in
            let showCallouts = !labels.isEmpty
            let artW = min(g.size.height * 0.62, showCallouts ? g.size.width * 0.40 : g.size.width)
            let artH = artW / 0.62
            let art = CGRect(x: (g.size.width - artW) / 2, y: (g.size.height - artH) / 2, width: artW, height: artH)

            ZStack(alignment: .topLeading) {
                MouseArt(highlighted: selected.flatMap(MousePart.init(rawValue:)), ledColor: ledColor)
                    .frame(width: art.width, height: art.height)
                    .offset(x: art.minX, y: art.minY)

                if showCallouts {
                    ForEach(MousePart.allCases, id: \.rawValue) { part in
                        if let text = labels[part.rawValue] {
                            Callout(part: part, text: text, art: art, width: g.size.width, selected: selected == part.rawValue)
                        }
                    }
                }

                ForEach(PhysicalButton.mt760) { b in
                    if let part = MousePart(rawValue: b.id) {
                        Button { onTap?(b) } label: {
                            Color.clear.frame(width: art.width * 0.2, height: art.width * 0.2).contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .focusEffectDisabled()
                        .help(b.name)
                        .position(x: art.minX + part.anchor.x * art.width, y: art.minY + part.anchor.y * art.height)
                    }
                }
            }
        }
    }
}

private struct Callout: View {
    let part: MousePart
    let text: String
    let art: CGRect
    let width: CGFloat
    let selected: Bool

    var body: some View {
        let a = CGPoint(x: art.minX + part.anchor.x * art.width, y: art.minY + part.anchor.y * art.height)
        let y = art.minY + part.callout.y * art.height
        let left = part.callout.leftSide
        let elbowX = left ? art.minX - 12 : art.maxX + 12
        let textW = max(0, left ? elbowX - 18 : width - elbowX - 18)
        ZStack(alignment: .topLeading) {
            Path { p in
                p.move(to: a)
                p.addLine(to: CGPoint(x: elbowX, y: y))
                p.addLine(to: CGPoint(x: left ? elbowX - 8 : elbowX + 8, y: y))
            }
            .stroke(selected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.tertiary),
                    style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
            Circle()
                .fill(selected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
                .frame(width: 5, height: 5)
                .position(a)
            VStack(alignment: left ? .trailing : .leading, spacing: 1) {
                Text(part.name).font(.caption2).foregroundStyle(.secondary)
                Text(text)
                    .font(.caption.weight(selected ? .semibold : .regular))
                    .foregroundStyle(selected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.primary))
                    .lineLimit(1)
            }
            .frame(width: textW, alignment: left ? .trailing : .leading)
            .position(x: left ? textW / 2 : elbowX + 18 + textW / 2, y: y)
        }
        .animation(.smooth(duration: 0.2), value: selected)
    }
}

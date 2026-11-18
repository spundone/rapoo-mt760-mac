import SwiftUI

// Original vector drawing of the MT760L's shape (top view): pointed left-button nose,
// big thumb wing, V-shaped button seams with the stage light and top button between
// them, a knurled main wheel and a knurled thumb wheel beside two slim side buttons.
// Coordinates are normalised to a box of `MouseArt.aspect` (width : height).

private func pt(_ r: CGRect, _ x: CGFloat, _ y: CGFloat) -> CGPoint {
    CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height)
}

/// Whole outline including the thumb wing.
struct MouseBodyShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(r, 0.27, 0.07))
        p.addCurve(to: pt(r, 0.41, 0.01), control1: pt(r, 0.27, 0.03), control2: pt(r, 0.34, 0.005))
        p.addCurve(to: pt(r, 0.80, 0.15), control1: pt(r, 0.58, 0.025), control2: pt(r, 0.72, 0.08))
        p.addCurve(to: pt(r, 0.97, 0.52), control1: pt(r, 0.90, 0.24), control2: pt(r, 0.98, 0.38))
        p.addCurve(to: pt(r, 0.80, 0.93), control1: pt(r, 0.96, 0.70), control2: pt(r, 0.90, 0.86))
        p.addCurve(to: pt(r, 0.45, 0.995), control1: pt(r, 0.70, 1.0), control2: pt(r, 0.55, 1.005))
        p.addCurve(to: pt(r, 0.10, 0.70), control1: pt(r, 0.30, 0.97), control2: pt(r, 0.16, 0.85))
        p.addCurve(to: pt(r, 0.01, 0.47), control1: pt(r, 0.05, 0.60), control2: pt(r, 0.0, 0.52))
        p.addCurve(to: pt(r, 0.22, 0.40), control1: pt(r, 0.03, 0.42), control2: pt(r, 0.13, 0.40))
        p.addCurve(to: pt(r, 0.27, 0.07), control1: pt(r, 0.27, 0.36), control2: pt(r, 0.25, 0.14))
        p.closeSubpath()
        return p
    }
}

/// Left button panel: from the nose back to the V seam.
struct LeftButtonShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(r, 0.27, 0.07))
        p.addCurve(to: pt(r, 0.41, 0.01), control1: pt(r, 0.27, 0.03), control2: pt(r, 0.34, 0.005))
        p.addCurve(to: pt(r, 0.525, 0.035), control1: pt(r, 0.46, 0.015), control2: pt(r, 0.50, 0.025))
        p.addLine(to: pt(r, 0.55, 0.285))
        p.addCurve(to: pt(r, 0.25, 0.385), control1: pt(r, 0.44, 0.32), control2: pt(r, 0.33, 0.36))
        p.addCurve(to: pt(r, 0.27, 0.07), control1: pt(r, 0.27, 0.30), control2: pt(r, 0.25, 0.14))
        p.closeSubpath()
        return p
    }
}

/// Right button panel: from the centre split to the right shoulder and back to the V seam.
struct RightButtonShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(r, 0.535, 0.035))
        p.addCurve(to: pt(r, 0.80, 0.15), control1: pt(r, 0.64, 0.05), control2: pt(r, 0.73, 0.09))
        p.addCurve(to: pt(r, 0.93, 0.40), control1: pt(r, 0.87, 0.21), control2: pt(r, 0.91, 0.30))
        p.addCurve(to: pt(r, 0.58, 0.29), control1: pt(r, 0.80, 0.37), control2: pt(r, 0.68, 0.32))
        p.closeSubpath()
        return p
    }
}

/// Thumb wing (the shelf on the left), for its own shading.
struct ThumbWingShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(r, 0.22, 0.40))
        p.addCurve(to: pt(r, 0.01, 0.47), control1: pt(r, 0.13, 0.40), control2: pt(r, 0.03, 0.42))
        p.addCurve(to: pt(r, 0.10, 0.70), control1: pt(r, 0.0, 0.52), control2: pt(r, 0.05, 0.60))
        p.addCurve(to: pt(r, 0.38, 0.93), control1: pt(r, 0.16, 0.82), control2: pt(r, 0.27, 0.90))
        p.addCurve(to: pt(r, 0.30, 0.62), control1: pt(r, 0.33, 0.83), control2: pt(r, 0.29, 0.72))
        p.addCurve(to: pt(r, 0.22, 0.40), control1: pt(r, 0.30, 0.52), control2: pt(r, 0.26, 0.44))
        p.closeSubpath()
        return p
    }
}

/// Parts of the mouse, keyed by firmware key ID.
enum MousePart: Int, CaseIterable {
    case left = 0, middle = 1, right = 2, bottom = 3, top = 4, forward = 5, back = 6, thumbWheel = 7

    var anchor: CGPoint {
        switch self {
        case .left: CGPoint(x: 0.38, y: 0.17)
        case .right: CGPoint(x: 0.76, y: 0.24)
        case .middle: CGPoint(x: 0.535, y: 0.16)
        case .top: CGPoint(x: 0.605, y: 0.37)
        case .forward: CGPoint(x: 0.255, y: 0.475)
        case .back: CGPoint(x: 0.245, y: 0.585)
        case .thumbWheel: CGPoint(x: 0.335, y: 0.53)
        case .bottom: CGPoint(x: 0.62, y: 0.90)
        }
    }

    /// Callout column and vertical slot (0…1 of the drawing height).
    var callout: (leftSide: Bool, y: CGFloat) {
        switch self {
        case .left: (true, 0.12)
        case .forward: (true, 0.44)
        case .thumbWheel: (true, 0.56)
        case .back: (true, 0.68)
        case .middle: (false, 0.08)
        case .right: (false, 0.22)
        case .top: (false, 0.38)
        case .bottom: (false, 0.84)
        }
    }

    var name: String {
        switch self {
        case .left: "Left button"
        case .right: "Right button"
        case .middle: "Wheel click"
        case .top: "Top button"
        case .forward: "Forward"
        case .back: "Back"
        case .thumbWheel: "Thumb wheel"
        case .bottom: "Bottom button"
        }
    }
}

/// The illustration itself, without callouts. Mica grey, like the real mouse.
struct MouseArt: View {
    static let aspect: CGFloat = 0.75
    var highlighted: MousePart?
    var ledColor: Color = .accentColor
    @Environment(\.colorScheme) private var scheme

    private let shellLight = Color(white: 0.93)
    private let shellDark = Color(white: 0.70)
    private let seam = Color.black.opacity(0.22)

    var body: some View {
        GeometryReader { g in
            let r = CGRect(origin: .zero, size: g.size)
            ZStack {
                // contact shadow
                MouseBodyShape()
                    .fill(.black.opacity(scheme == .dark ? 0.6 : 0.22))
                    .blur(radius: r.width * 0.045)
                    .offset(x: r.width * 0.01, y: r.height * 0.025)
                    .scaleEffect(0.96)

                // shell
                MouseBodyShape()
                    .fill(LinearGradient(colors: [shellLight, shellDark], startPoint: .topLeading, endPoint: .bottomTrailing))
                MouseBodyShape()
                    .fill(RadialGradient(colors: [.white.opacity(0.55), .clear],
                                         center: UnitPoint(x: 0.62, y: 0.62), startRadius: 0, endRadius: r.width * 0.45))

                // thumb wing, slightly darker with contour grooves
                ThumbWingShape()
                    .fill(LinearGradient(colors: [Color(white: 0.80), Color(white: 0.66)], startPoint: .top, endPoint: .bottom))
                ForEach(0..<3, id: \.self) { i in
                    let k = CGFloat(i) * 0.05
                    Path { p in
                        p.move(to: pt(r, 0.06 + k * 0.6, 0.58 + k))
                        p.addCurve(to: pt(r, 0.34 - k * 0.3, 0.90 - k * 0.2),
                                   control1: pt(r, 0.10 + k, 0.74 + k), control2: pt(r, 0.22, 0.86))
                    }
                    .stroke(.black.opacity(0.07), lineWidth: 1)
                }

                // button panels
                LeftButtonShape()
                    .fill(LinearGradient(colors: [Color(white: 0.97), Color(white: 0.84)], startPoint: .top, endPoint: .bottom))
                RightButtonShape()
                    .fill(LinearGradient(colors: [Color(white: 0.96), Color(white: 0.82)], startPoint: .topLeading, endPoint: .bottomTrailing))
                LeftButtonShape().stroke(seam, lineWidth: 1)
                RightButtonShape().stroke(seam, lineWidth: 1)
                MouseBodyShape()
                    .stroke(LinearGradient(colors: [.white.opacity(0.9), .black.opacity(0.25)], startPoint: .top, endPoint: .bottom),
                            lineWidth: 1)

                // wheel slot and knurled metal wheel
                RoundedRectangle(cornerRadius: r.width * 0.02)
                    .fill(Color(white: 0.25))
                    .frame(width: r.width * 0.085, height: r.height * 0.15)
                    .rotationEffect(.degrees(-8))
                    .position(pt(r, 0.535, 0.16))
                KnurledWheel(horizontalRidges: true, highlighted: highlighted == .middle)
                    .frame(width: r.width * 0.065, height: r.height * 0.13)
                    .rotationEffect(.degrees(-8))
                    .position(pt(r, 0.535, 0.16))

                // stage light and top button between the V seams
                Circle().fill(ledColor)
                    .frame(width: r.width * 0.016)
                    .shadow(color: ledColor.opacity(0.9), radius: r.width * 0.02)
                    .position(pt(r, 0.565, 0.315))
                Capsule()
                    .fill(LinearGradient(colors: [Color(white: 0.98), Color(white: 0.72)], startPoint: .leading, endPoint: .trailing))
                    .overlay(Capsule().stroke(seam, lineWidth: 1))
                    .frame(width: r.width * 0.032, height: r.height * 0.06)
                    .rotationEffect(.degrees(-12))
                    .position(pt(r, 0.605, 0.37))

                // side buttons and thumb wheel
                sideButton(r).rotationEffect(.degrees(-6)).position(pt(r, 0.255, 0.475))
                sideButton(r).rotationEffect(.degrees(-4)).position(pt(r, 0.245, 0.585))
                RoundedRectangle(cornerRadius: r.width * 0.015)
                    .fill(Color(white: 0.3))
                    .frame(width: r.width * 0.09, height: r.height * 0.12)
                    .rotationEffect(.degrees(-6))
                    .position(pt(r, 0.335, 0.53))
                KnurledWheel(horizontalRidges: false, highlighted: highlighted == .thumbWheel)
                    .frame(width: r.width * 0.075, height: r.height * 0.105)
                    .rotationEffect(.degrees(-6))
                    .position(pt(r, 0.335, 0.53))

                // glow on the selected part
                if let h = highlighted {
                    Circle()
                        .fill(Color.accentColor.opacity(0.4))
                        .frame(width: r.width * 0.15)
                        .blur(radius: r.width * 0.03)
                        .position(pt(r, h.anchor.x, h.anchor.y))
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
        }
        .aspectRatio(Self.aspect, contentMode: .fit)
        .animation(.smooth(duration: 0.25), value: highlighted)
    }

    private func sideButton(_ r: CGRect) -> some View {
        RoundedRectangle(cornerRadius: r.width * 0.012)
            .fill(LinearGradient(colors: [Color(white: 0.95), Color(white: 0.74)], startPoint: .leading, endPoint: .trailing))
            .overlay(RoundedRectangle(cornerRadius: r.width * 0.012).stroke(seam, lineWidth: 1))
            .frame(width: r.width * 0.035, height: r.height * 0.085)
    }
}

/// Brushed-metal wheel with knurled ridges.
private struct KnurledWheel: View {
    var horizontalRidges: Bool
    var highlighted: Bool

    var body: some View {
        GeometryReader { g in
            let n = horizontalRidges ? 12 : 9
            ZStack {
                RoundedRectangle(cornerRadius: min(g.size.width, g.size.height) * 0.2)
                    .fill(LinearGradient(colors: [Color(white: 0.62), Color(white: 0.95), Color(white: 0.55)],
                                         startPoint: horizontalRidges ? .leading : .top,
                                         endPoint: horizontalRidges ? .trailing : .bottom))
                if horizontalRidges {
                    VStack(spacing: 0) {
                        ForEach(0..<n, id: \.self) { _ in
                            Spacer(minLength: 0)
                            Rectangle().fill(.black.opacity(0.28)).frame(height: max(1, g.size.height * 0.018))
                        }
                        Spacer(minLength: 0)
                    }
                } else {
                    HStack(spacing: 0) {
                        ForEach(0..<n, id: \.self) { _ in
                            Spacer(minLength: 0)
                            Rectangle().fill(.black.opacity(0.28)).frame(width: max(1, g.size.width * 0.025))
                        }
                        Spacer(minLength: 0)
                    }
                }
                if highlighted {
                    RoundedRectangle(cornerRadius: min(g.size.width, g.size.height) * 0.2)
                        .stroke(Color.accentColor, lineWidth: 1.5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: min(g.size.width, g.size.height) * 0.2))
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
            let artW = min(g.size.height * MouseArt.aspect, showCallouts ? g.size.width * 0.44 : g.size.width)
            let artH = artW / MouseArt.aspect
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
                            Color.clear.frame(width: art.width * 0.16, height: art.width * 0.16).contentShape(Circle())
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
        let dashed = part == .bottom
        ZStack(alignment: .topLeading) {
            Path { p in
                p.move(to: a)
                p.addLine(to: CGPoint(x: elbowX, y: y))
                p.addLine(to: CGPoint(x: left ? elbowX - 8 : elbowX + 8, y: y))
            }
            .stroke(selected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.tertiary),
                    style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round, dash: dashed ? [3, 3] : []))
            Circle()
                .fill(selected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color(white: 0.35)))
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

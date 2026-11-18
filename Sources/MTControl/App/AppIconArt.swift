import SwiftUI
import AppKit

/// The app icon, drawn from the same mouse shape as the in-app illustration.
/// 1024 × 1024 canvas with an 824 pt rounded square, matching Apple's macOS icon grid.
struct AppIconArt: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.20, green: 0.21, blue: 0.25), Color(red: 0.06, green: 0.06, blue: 0.08)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: 185, style: .continuous)
                        .fill(RadialGradient(colors: [Color(red: 0.25, green: 0.45, blue: 1.0).opacity(0.35), .clear],
                                             center: UnitPoint(x: 0.5, y: 0.78), startRadius: 0, endRadius: 520))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 185, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [.white.opacity(0.28), .white.opacity(0.04)], startPoint: .top, endPoint: .bottom),
                                      lineWidth: 3)
                )
                .frame(width: 824, height: 824)

            ZStack {
                MouseBodyShape()
                    .fill(.black.opacity(0.6))
                    .blur(radius: 26)
                    .offset(x: 10, y: 28)
                MouseBodyShape()
                    .fill(LinearGradient(colors: [Color(white: 0.99), Color(white: 0.78)], startPoint: .topLeading, endPoint: .bottomTrailing))
                MouseBodyShape()
                    .fill(RadialGradient(colors: [.white.opacity(0.7), .clear], center: UnitPoint(x: 0.4, y: 0.6), startRadius: 0, endRadius: 200))
                MouseSeams()
                    .stroke(.black.opacity(0.18), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                // wheel
                Capsule()
                    .fill(Color(white: 0.16))
                    .frame(width: 36, height: 102)
                    .position(x: 0.525 * 360, y: 0.175 * 580)
                Capsule()
                    .fill(LinearGradient(colors: [Color(red: 0.35, green: 0.62, blue: 1.0), Color(red: 0.0, green: 0.36, blue: 0.95)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 22, height: 84)
                    .shadow(color: Color(red: 0.2, green: 0.5, blue: 1).opacity(0.8), radius: 12)
                    .position(x: 0.525 * 360, y: 0.175 * 580)
                // stage light
                Circle()
                    .fill(Color(red: 0.4, green: 0.7, blue: 1))
                    .frame(width: 14, height: 14)
                    .shadow(color: Color(red: 0.3, green: 0.6, blue: 1), radius: 10)
                    .position(x: 0.525 * 360, y: 0.37 * 580)
            }
            .frame(width: 360, height: 580)
            .rotationEffect(.degrees(-14))
            .offset(y: 6)
        }
        .frame(width: 1024, height: 1024)
    }

    /// `MTControl --render-art DIR` writes light and dark previews of the mouse diagram.
    @MainActor
    static func renderArtPreviewIfRequested() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--render-art"), i + 1 < args.count else { return }
        let dir = URL(fileURLWithPath: args[i + 1])
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let labels: [Int: String] = [0: "Left click", 2: "Right click", 1: "Gesture button", 5: "Forward",
                                     6: "Back", 4: "DPI cycle · 1800", 7: "Horizontal scroll"]
        for scheme in [ColorScheme.light, .dark] {
            let view = MouseDiagram(selected: 1, labels: labels)
                .frame(width: 640, height: 380)
                .padding(24)
                .background(scheme == .dark ? Color(white: 0.12) : Color(white: 0.96))
                .environment(\.colorScheme, scheme)
            let r = ImageRenderer(content: view)
            r.scale = 2
            if let cg = r.cgImage {
                try? NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])?
                    .write(to: dir.appending(path: "diagram-\(scheme == .dark ? "dark" : "light").png"))
            }
        }
        exit(0)
    }

    /// `MTControl --render-icon DIR` writes an .iconset into DIR and exits.
    @MainActor
    static func renderIconSetIfRequested() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--render-icon"), i + 1 < args.count else { return }
        let dir = URL(fileURLWithPath: args[i + 1])
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (base, scales) in [(16, [1, 2]), (32, [1, 2]), (128, [1, 2]), (256, [1, 2]), (512, [1, 2])] {
            for scale in scales {
                let renderer = ImageRenderer(content: AppIconArt())
                renderer.scale = CGFloat(base * scale) / 1024
                guard let cg = renderer.cgImage else { continue }
                let rep = NSBitmapImageRep(cgImage: cg)
                let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
                try? rep.representation(using: .png, properties: [:])?.write(to: dir.appending(path: name))
            }
        }
        exit(0)
    }
}

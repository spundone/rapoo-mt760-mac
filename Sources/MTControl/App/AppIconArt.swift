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

            MouseArt(highlighted: .middle, ledColor: Color(red: 0.35, green: 0.65, blue: 1.0))
                .tint(Color(red: 0.25, green: 0.55, blue: 1.0))
                .environment(\.colorScheme, .dark)
                .frame(width: 470, height: 470 / MouseArt.aspect)
            .rotationEffect(.degrees(-10))
            .offset(x: 10, y: 4)
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
                                     6: "Back", 4: "Middle click", 3: "DPI cycle −", 7: "Horizontal scroll"]
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

import CoreText
import AppKit
import SwiftUI

enum OP1Assets {
    private static var didRegisterFonts = false

    static func registerFonts() {
        guard !didRegisterFonts else {
            return
        }

        didRegisterFonts = true

        let fontURLs = Bundle.main.urls(
            forResourcesWithExtension: "ttf",
            subdirectory: "Resources/Fonts"
        ) ?? []

        for url in fontURLs {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

enum OP1FontWeight {
    case thin
    case light
    case regular
    case medium
    case bold
    case extraBold
    case black

    var fontName: String {
        switch self {
        case .thin: return "Heebo-Thin"
        case .light: return "Heebo-Light"
        case .regular: return "Heebo-Regular"
        case .medium: return "Heebo-Medium"
        case .bold: return "Heebo-Bold"
        case .extraBold: return "Heebo-ExtraBold"
        case .black: return "Heebo-Black"
        }
    }
}

extension Font {
    static func heebo(size: CGFloat, weight: OP1FontWeight = .light) -> Font {
        .custom(weight.fontName, size: size)
    }
}

struct OP1BundleImage: View {
    let name: String
    let fileExtension: String

    init(_ name: String, fileExtension: String = "pdf") {
        self.name = name
        self.fileExtension = fileExtension
    }

    var body: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Color.clear
        }
    }

    private var image: NSImage? {
        guard let url = Bundle.main.url(
            forResource: name,
            withExtension: fileExtension,
            subdirectory: "Resources/Images"
        ) else {
            return nil
        }

        return NSImage(contentsOf: url)
    }
}

struct OP1CategoryIcon: View {
    let category: PatchCategory
    let color: Color

    var body: some View {
        switch category {
        case .synth:
            OP1SynthIcon(color: color)
        case .drum:
            OP1DrumIcon(color: color)
        case .sampler:
            OP1SamplerIcon(color: color)
        }
    }
}

struct OP1GearIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let geometry = OP1IconGeometry(viewBox: CGRect(x: 0, y: 0, width: 32, height: 32), in: rect)
        var path = Path()

        path.move(to: geometry.point(14, 0))
        path.addLine(to: geometry.point(18, 0))
        path.addLine(to: geometry.point(19, 6))
        path.addLine(to: geometry.point(20.707, 6.707))
        path.addLine(to: geometry.point(26, 3.293))
        path.addLine(to: geometry.point(28.707, 6))
        path.addLine(to: geometry.point(25.293, 11.293))
        path.addLine(to: geometry.point(26, 13))
        path.addLine(to: geometry.point(32, 14))
        path.addLine(to: geometry.point(32, 18))
        path.addLine(to: geometry.point(26, 19))
        path.addLine(to: geometry.point(25.293, 20.707))
        path.addLine(to: geometry.point(28.707, 26))
        path.addLine(to: geometry.point(26, 28.707))
        path.addLine(to: geometry.point(20.707, 25.293))
        path.addLine(to: geometry.point(19, 26))
        path.addLine(to: geometry.point(18, 32))
        path.addLine(to: geometry.point(14, 32))
        path.addLine(to: geometry.point(13, 26))
        path.addLine(to: geometry.point(11.293, 25.293))
        path.addLine(to: geometry.point(6, 28.707))
        path.addLine(to: geometry.point(3.293, 26))
        path.addLine(to: geometry.point(6.707, 20.707))
        path.addLine(to: geometry.point(6, 19))
        path.addLine(to: geometry.point(0, 18))
        path.addLine(to: geometry.point(0, 14))
        path.addLine(to: geometry.point(6, 13))
        path.addLine(to: geometry.point(6.707, 11.293))
        path.addLine(to: geometry.point(3.293, 6))
        path.addLine(to: geometry.point(6, 3.293))
        path.addLine(to: geometry.point(11.293, 6.707))
        path.addLine(to: geometry.point(13, 6))
        path.closeSubpath()
        path.addEllipse(in: geometry.rect(x: 10, y: 10, width: 12, height: 12))

        return path
    }
}

struct OP1FolderIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let geometry = OP1IconGeometry(viewBox: CGRect(x: 0, y: 0, width: 32, height: 32), in: rect)
        var path = Path()

        path.move(to: geometry.point(0, 4))
        path.addLine(to: geometry.point(0, 28))
        path.addLine(to: geometry.point(32, 28))
        path.addLine(to: geometry.point(32, 8))
        path.addLine(to: geometry.point(16, 8))
        path.addLine(to: geometry.point(12, 4))
        path.closeSubpath()

        return path
    }
}

private struct OP1SynthIcon: View {
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let geometry = OP1IconGeometry(
                viewBox: CGRect(x: 0, y: 0, width: 42.281, height: 21.487),
                in: CGRect(origin: .zero, size: proxy.size)
            )

            Path { path in
                path.move(to: geometry.point(41.531, 4.139))
                path.addCurve(
                    to: geometry.point(38.137, 0.75),
                    control1: geometry.point(41.531, 2.267),
                    control2: geometry.point(40.01, 0.75)
                )
                path.addCurve(
                    to: geometry.point(34.744, 4.139),
                    control1: geometry.point(36.264, 0.75),
                    control2: geometry.point(34.744, 2.267)
                )
                path.addLine(to: geometry.point(34.775, 17.345))
                path.addCurve(
                    to: geometry.point(31.38, 20.737),
                    control1: geometry.point(34.775, 19.218),
                    control2: geometry.point(33.254, 20.737)
                )
                path.addCurve(
                    to: geometry.point(27.988, 17.345),
                    control1: geometry.point(29.505, 20.737),
                    control2: geometry.point(27.988, 19.218)
                )
                path.addLine(to: geometry.point(27.988, 4.139))
                path.addCurve(
                    to: geometry.point(24.598, 0.75),
                    control1: geometry.point(27.988, 2.267),
                    control2: geometry.point(26.467, 0.75)
                )
                path.addCurve(
                    to: geometry.point(21.202, 4.139),
                    control1: geometry.point(22.723, 0.75),
                    control2: geometry.point(21.202, 2.267)
                )
                path.addLine(to: geometry.point(21.122, 17.345))
                path.addCurve(
                    to: geometry.point(17.731, 20.737),
                    control1: geometry.point(21.122, 19.218),
                    control2: geometry.point(19.603, 20.737)
                )
                path.addCurve(
                    to: geometry.point(14.338, 17.345),
                    control1: geometry.point(15.859, 20.737),
                    control2: geometry.point(14.338, 19.218)
                )
                path.addLine(to: geometry.point(14.338, 4.139))
                path.addCurve(
                    to: geometry.point(10.946, 0.75),
                    control1: geometry.point(14.338, 2.267),
                    control2: geometry.point(12.82, 0.75)
                )
                path.addCurve(
                    to: geometry.point(7.55, 4.139),
                    control1: geometry.point(9.07, 0.75),
                    control2: geometry.point(7.55, 2.267)
                )
                path.addLine(to: geometry.point(7.531, 17.343))
                path.addCurve(
                    to: geometry.point(4.142, 20.735),
                    control1: geometry.point(7.531, 19.217),
                    control2: geometry.point(6.012, 20.735)
                )
                path.addCurve(
                    to: geometry.point(0.75, 17.343),
                    control1: geometry.point(2.267, 20.735),
                    control2: geometry.point(0.75, 19.217)
                )
            }
            .stroke(
                color,
                style: StrokeStyle(lineWidth: geometry.strokeWidth(1.5), lineCap: .square)
            )
        }
    }
}

private struct OP1SamplerIcon: View {
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let geometry = OP1IconGeometry(
                viewBox: CGRect(x: -457.3, y: 270.8, width: 40.8, height: 21.5),
                in: CGRect(origin: .zero, size: proxy.size)
            )

            Path { path in
                path.move(to: geometry.point(-417.3, 277.4))
                path.addCurve(
                    to: geometry.point(-420.6, 274.1),
                    control1: geometry.point(-417.3, 275.6),
                    control2: geometry.point(-418.8, 274.1)
                )
                path.addCurve(
                    to: geometry.point(-423.9, 277.4),
                    control1: geometry.point(-422.4, 274.1),
                    control2: geometry.point(-423.9, 275.6)
                )
                path.addLine(to: geometry.point(-423.9, 288.3))
                path.addCurve(
                    to: geometry.point(-427.2, 291.6),
                    control1: geometry.point(-423.9, 290.1),
                    control2: geometry.point(-425.4, 291.6)
                )
                path.addCurve(
                    to: geometry.point(-430.5, 288.3),
                    control1: geometry.point(-429, 291.6),
                    control2: geometry.point(-430.5, 290.1)
                )
                path.addLine(to: geometry.point(-430.5, 279.8))
                path.addCurve(
                    to: geometry.point(-433.8, 276.5),
                    control1: geometry.point(-430.5, 278),
                    control2: geometry.point(-432, 276.5)
                )
                path.addCurve(
                    to: geometry.point(-437.1, 279.8),
                    control1: geometry.point(-435.6, 276.5),
                    control2: geometry.point(-437.1, 278)
                )
                path.addLine(to: geometry.point(-437.1, 280.8))
                path.addCurve(
                    to: geometry.point(-440.4, 284.1),
                    control1: geometry.point(-437.1, 282.6),
                    control2: geometry.point(-438.6, 284.1)
                )
                path.addCurve(
                    to: geometry.point(-443.7, 280.8),
                    control1: geometry.point(-442.2, 284.1),
                    control2: geometry.point(-443.7, 282.6)
                )
                path.addLine(to: geometry.point(-443.7, 274.8))
                path.addCurve(
                    to: geometry.point(-447, 271.5),
                    control1: geometry.point(-443.7, 273),
                    control2: geometry.point(-445.2, 271.5)
                )
                path.addCurve(
                    to: geometry.point(-450.3, 274.8),
                    control1: geometry.point(-448.8, 271.5),
                    control2: geometry.point(-450.3, 273)
                )
                path.addLine(to: geometry.point(-450.3, 283.3))
                path.addCurve(
                    to: geometry.point(-453.6, 286.6),
                    control1: geometry.point(-450.3, 285.1),
                    control2: geometry.point(-451.8, 286.6)
                )
                path.addCurve(
                    to: geometry.point(-456.9, 283.3),
                    control1: geometry.point(-455.4, 286.6),
                    control2: geometry.point(-456.9, 285.1)
                )
            }
            .stroke(
                color,
                style: StrokeStyle(lineWidth: geometry.strokeWidth(1.5), lineCap: .square)
            )
        }
    }
}

private struct OP1DrumIcon: View {
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let geometry = OP1IconGeometry(
                viewBox: CGRect(x: 0, y: 0, width: 16.308, height: 18.638),
                in: CGRect(origin: .zero, size: proxy.size)
            )

            ZStack {
                Path { path in
                    path.addEllipse(in: geometry.rect(x: 1, y: 1, width: 14.308, height: 14.308))
                }
                .stroke(color, lineWidth: geometry.strokeWidth(2))

                Path { path in
                    path.move(to: geometry.point(8.154, 18.638))
                    path.addLine(to: geometry.point(8.154, 9.572))
                }
                .stroke(color, lineWidth: geometry.strokeWidth(2))

                Path { path in
                    path.addEllipse(in: geometry.rect(x: 6.738, y: 8.085, width: 2.833, height: 2.833))
                }
                .fill(color)
            }
        }
    }
}

private struct OP1IconGeometry {
    let viewBox: CGRect
    let scale: CGFloat
    let origin: CGPoint

    init(viewBox: CGRect, in rect: CGRect) {
        self.viewBox = viewBox
        scale = min(rect.width / viewBox.width, rect.height / viewBox.height)
        origin = CGPoint(
            x: rect.minX + (rect.width - viewBox.width * scale) / 2,
            y: rect.minY + (rect.height - viewBox.height * scale) / 2
        )
    }

    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(
            x: origin.x + (x - viewBox.minX) * scale,
            y: origin.y + (y - viewBox.minY) * scale
        )
    }

    func rect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> CGRect {
        CGRect(
            x: point(x, y).x,
            y: point(x, y).y,
            width: width * scale,
            height: height * scale
        )
    }

    func strokeWidth(_ value: CGFloat) -> CGFloat {
        max(0.75, value * scale)
    }
}

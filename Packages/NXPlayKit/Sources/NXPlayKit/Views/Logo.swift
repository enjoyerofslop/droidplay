import SwiftUI

/// DroidPlay's logo: the app icon as App/AppIcon.icon draws it, flat (no glass). Its light green tile tells it apart
/// from NX Play's logo, whose controller is the same: the bare artwork, which this drew before, read as NX Play's.
/// The tile is icon.json's fill; the artwork is the SVGs' (Assets: plate.svg, joycons.svg, play.svg), in their own
/// 1024-point canvas, scaled about its center as they scale it. Colors are the SVGs' untagged ones and the fill's, which
/// the icon reads as Display P3.
struct Logo: View {
    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            context.translateBy(x: (size.width - side) / 2, y: (size.height - side) / 2)
            context.scaleBy(x: side / Self.canvas, y: side / Self.canvas)

            // the tile: Big Sur's rounded square, icon.json's gradient from top to bottom
            let tile = RoundedRectangle(cornerRadius: Self.canvas * 0.2237, style: .continuous)
                .path(in: CGRect(x: 0, y: 0, width: Self.canvas, height: Self.canvas))
            context.fill(
                tile,
                with: .linearGradient(
                    Gradient(colors: [
                        Color(.displayP3, red: 0.62, green: 0.91, blue: 0.68),
                        Color(.displayP3, red: 0.28, green: 0.73, blue: 0.46),
                    ]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: Self.canvas)))

            // the SVGs' own transform: translate(512 512) scale(1.5161) translate(-512 -512)
            context.translateBy(x: Self.canvas / 2, y: Self.canvas / 2)
            context.scaleBy(x: 1.5161, y: 1.5161)
            context.translateBy(x: -Self.canvas / 2, y: -Self.canvas / 2)

            // the plate between the Joy-Cons, under their inner edges
            let plate = RoundedRectangle(cornerRadius: 26).path(
                in: CGRect(x: 413, y: 334, width: 198, height: 356))
            context.fill(plate, with: .color(Self.p3(0x3a3f4b)))
            context.stroke(plate, with: .color(Self.p3(0x4a505e)), lineWidth: 4)

            // left Joy-Con: the stick and the four direction buttons
            context.fill(
                UnevenRoundedRectangle(topLeadingRadius: 80, bottomLeadingRadius: 80).path(
                    in: CGRect(x: 255, y: 322, width: 160, height: 380)),
                with: .color(Self.p3(0x00b8d9)))
            for (x, y, r) in [
                (335.0, 432.0, 36.0), (335, 556, 15), (335, 624, 15), (301, 590, 15),
                (369, 590, 15),
            ] {
                context.fill(Self.circle(x, y, r), with: .color(Self.p3(0x0a5f70)))
            }

            // right Joy-Con: the four face buttons and the stick
            context.fill(
                UnevenRoundedRectangle(bottomTrailingRadius: 80, topTrailingRadius: 80).path(
                    in: CGRect(x: 609, y: 322, width: 160, height: 380)),
                with: .color(Self.p3(0xff4f5e)))
            for (x, y, r) in [
                (689.0, 398.0, 15.0), (689, 466, 15), (655, 432, 15), (723, 432, 15),
                (689, 590, 36),
            ] {
                context.fill(Self.circle(x, y, r), with: .color(Self.p3(0x8a1d27)))
            }

            // the play button on the plate, its corners rounded by a wide stroke
            var play = Path()
            play.move(to: CGPoint(x: 490, y: 476))
            play.addLine(to: CGPoint(x: 490, y: 548))
            play.addLine(to: CGPoint(x: 550, y: 512))
            play.closeSubpath()
            context.fill(play, with: .color(.white))
            context.stroke(
                play, with: .color(.white), style: StrokeStyle(lineWidth: 26, lineJoin: .round))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    /// The icon's canvas, in the SVGs' points.
    static let canvas = 1024.0

    private static func circle(_ x: Double, _ y: Double, _ r: Double) -> Path {
        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
    }

    private static func p3(_ hex: Int) -> Color {
        Color(
            .displayP3, red: Double(hex >> 16 & 0xff) / 255, green: Double(hex >> 8 & 0xff) / 255,
            blue: Double(hex & 0xff) / 255)
    }
}

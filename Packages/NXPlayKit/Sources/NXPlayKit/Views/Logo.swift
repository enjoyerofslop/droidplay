import SwiftUI

/// DroidPlay's logo: the app icon's artwork without its background (App/AppIcon.icon/Assets: plate.svg, joycons.svg,
/// play.svg), in the SVGs' own coordinates, cropped to the controller (x 255–769, y 322–702). Its colors are the SVGs'
/// untagged ones, which the icon reads as Display P3.
struct Logo: View {
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / Self.bounds.width, size.height / Self.bounds.height)
            context.translateBy(
                x: (size.width - Self.bounds.width * scale) / 2,
                y: (size.height - Self.bounds.height * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -Self.bounds.minX, y: -Self.bounds.minY)

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
        .aspectRatio(Self.bounds.width / Self.bounds.height, contentMode: .fit)
        .accessibilityHidden(true)
    }

    static let bounds = CGRect(x: 255, y: 322, width: 514, height: 380)

    private static func circle(_ x: Double, _ y: Double, _ r: Double) -> Path {
        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
    }

    private static func p3(_ hex: Int) -> Color {
        Color(
            .displayP3, red: Double(hex >> 16 & 0xff) / 255, green: Double(hex >> 8 & 0xff) / 255,
            blue: Double(hex & 0xff) / 255)
    }
}

import AppKit
import SwiftUI

/// DroidPlay › About DroidPlay: the standard panel (icon, name, version) with credits: who makes it, where it lives, what it
/// builds on. The copyright line comes from Info.plist (NSHumanReadableCopyright, project.yml).
public struct AboutMenuItem: View {
    public init() {}

    public var body: some View {
        Button("About DroidPlay") {
            NSApp.orderFrontStandardAboutPanel(options: [.credits: Self.credits])
            NSApp.activate()
        }
    }

    static let repository = URL(string: "https://github.com/enjoyerofslop/droidplay")!

    /// Centred lines, small text, links in the accent colour; the panel scrolls them if they run long.
    static var credits: NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.paragraphSpacing = 6
        let base: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph,
        ]
        let text = NSMutableAttributedString()
        func line(_ parts: [(String, URL?)]) {
            for (part, link) in parts {
                var attributes = base
                if let link { attributes[.link] = link }
                text.append(NSAttributedString(string: part, attributes: attributes))
            }
            text.append(NSAttributedString(string: "\n", attributes: base))
        }
        line([("Switch games on your Mac, iPhone and iPad, from the games you own.", nil)])
        line([("Made by Oleh Khomei", nil)])
        line([
            ("GitHub", repository), (" · ", nil),
            ("Releases", repository.appending(path: "releases")), (" · ", nil),
            ("Report a Problem", repository.appending(path: "issues")),
        ])
        line([
            ("Builds on ", nil), ("nxnative", URL(string: "https://github.com/seedds/nxnative")!),
            (" by seedds and its contributors", nil),
        ])
        line([("MIT License", repository.appending(path: "blob/main/LICENSE"))])
        text.deleteCharacters(in: NSRange(location: text.length - 1, length: 1))  // no blank line at the end
        return text
    }
}

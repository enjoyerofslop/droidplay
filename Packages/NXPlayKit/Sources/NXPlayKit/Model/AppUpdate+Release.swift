import Foundation
import Security

/// What GitHub's latest release and the running app's signature say: the version to compare, and whether this copy
/// may install it.
extension AppUpdater {
    struct Release {
        let version: String
        let notes: String
        let dmg: URL
        let sha256: String

        /// GitHub's latest release: tag v<version>, a .dmg asset with its digest ("sha256:…"); nil without them.
        init?(json data: Data) {
            guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let tag = object["tag_name"] as? String,
                let assets = object["assets"] as? [[String: Any]],
                let asset = assets.first(where: {
                    ($0["name"] as? String)?.hasSuffix(".dmg") == true
                }),
                let link = asset["browser_download_url"] as? String, let url = URL(string: link),
                url.scheme == "https",
                let digest = asset["digest"] as? String, digest.hasPrefix("sha256:")
            else { return nil }
            version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            notes = object["body"] as? String ?? ""
            dmg = url
            sha256 = String(digest.dropFirst("sha256:".count))
        }
    }

    /// GitHub's latest release as a copy that only tells about it reads it: no DMG or digest needed, since nothing is
    /// downloaded, but the page the player gets it from.
    struct ReleasePage {
        let tag: String
        let version: String
        let notes: String
        let page: URL

        init?(json data: Data) {
            guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let tag = object["tag_name"] as? String, !tag.isEmpty
            else { return nil }
            self.tag = tag
            version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            notes = object["body"] as? String ?? ""
            // the browser opens only a page on GitHub itself; anything else gets the releases list
            let link = (object["html_url"] as? String).flatMap(URL.init(string:))
            page =
                link.flatMap { $0.scheme == "https" && $0.host() == "github.com" ? $0 : nil }
                ?? AppUpdater.releasesPage
        }
    }

    nonisolated static let releasesPage = URL(
        string: "https://github.com/enjoyerofslop/droidplay/releases")!

    /// CHANGELOG.md as the release's tag has it: the notes of every release up to it.
    nonisolated static func changelog(at tag: String) -> URL? {
        tag.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed).flatMap {
            URL(string: "https://raw.githubusercontent.com/enjoyerofslop/droidplay/\($0)/CHANGELOG.md")
        }
    }

    nonisolated static func isNewer(_ version: String, than current: String) -> Bool {
        let parts = { (v: String) in v.split(separator: ".").map { Int($0) ?? 0 } }
        let a = parts(version)
        let b = parts(current)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    /// The team in the running app's signature; nil when it is ad hoc (a build from the checkout, or a DroidPlay
    /// release).
    nonisolated static func ownTeamID() -> String? {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else {
            return nil
        }
        var info: CFDictionary?
        guard
            SecCodeCopySigningInformation(
                staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info)
                == errSecSuccess
        else { return nil }
        return (info as? [String: Any])?[kSecCodeInfoTeamIdentifier as String] as? String
    }
}

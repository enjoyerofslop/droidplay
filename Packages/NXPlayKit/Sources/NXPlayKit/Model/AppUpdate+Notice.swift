import Foundation

/// A DroidPlay release signed ad hoc, as every one is, can't safely replace itself: with no team and no notarization,
/// nothing proves a download is DroidPlay's. So it only tells the player: at launch and once a day it asks GitHub for
/// the latest release and, when that's newer, shows its version, its notes and a link to its page, where the player
/// downloads it. It fetches only that release's details and its changelog's text, never the app.
extension AppUpdater {
    /// How a copy of DroidPlay hears of a new release.
    public enum Mode: Sendable {
        /// Released with a Developer ID: it downloads, checks and installs the release.
        case install
        /// Released ad hoc: it says the release is out and links to its page.
        case notify
        /// Built from the checkout: git pull and bin/install update it.
        case off

        init(teamID: String?, fromCheckout: Bool) {
            self = fromCheckout ? .off : teamID != nil ? .install : .notify
        }
    }

    /// GitHub's answer for a URL: its body and HTTP status.
    typealias Fetch = @Sendable (URL) async throws -> (Data, Int)

    static let fetchFromGitHub: Fetch = { url in
        let (data, response) = try await URLSession.shared.data(from: url)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }

    /// A newer DroidPlay to tell the player about, the same way wherever it shows.
    public struct Notice: Equatable, Sendable {
        public let version: String
        public let notes: Changelog
        /// Where to download it, for a copy that doesn't install it; nil when it's staged and installs on quit.
        public let page: URL?
    }

    /// The update the library's banner, Console Mode's pill and its card show; nil when there's none.
    public var notice: Notice? {
        switch state {
        case .ready(let version, let notes): Notice(version: version, notes: notes, page: nil)
        case .available(let version, let notes, let page):
            Notice(version: version, notes: notes, page: page)
        default: nil
        }
    }

    /// The release's page in the browser, where the player downloads it.
    public func openReleasePage() {
        guard case .available(_, _, let page) = state else { return }
        openPage(page)
    }

    /// Mode.notify's check: the latest release and, when it's newer than this copy, what it changes.
    func lookForRelease() async {
        // a notice already up stays while GitHub is asked again, and when asking fails: it's still true
        let shown = state
        switch state {
        case .checking: return
        case .available: break
        default: state = .checking
        }
        do {
            let (data, status) = try await fetch(Self.latestRelease)
            guard status == 200 else { throw UpdateError("GitHub didn't answer") }
            lastCheck = .now
            guard let release = ReleasePage(json: data),
                Self.isNewer(release.version, than: currentVersion)
            else {
                state = .upToDate
                return
            }
            let notes = await whatsNew(in: release)
            state = .available(version: release.version, notes: notes, page: release.page)
        } catch {
            if case .available = shown {
                state = shown
            } else {
                state = .failed((error as? UpdateError)?.message ?? error.localizedDescription)
            }
        }
    }

    /// Every release since this one, from the changelog at the release's tag (a skipped release's changes too), as a
    /// staged update's What's New reads them from its app; the release's own notes when that changelog can't be read.
    private func whatsNew(in release: ReleasePage) async -> Changelog {
        if let url = Self.changelog(at: release.tag), let answer = try? await fetch(url),
            answer.1 == 200
        {
            let releases = Changelog(markdown: String(decoding: answer.0, as: UTF8.self))
                .releases(after: currentVersion, upTo: release.version)
            if !releases.isEmpty { return releases }
        }
        return Self.releaseNotes(release.notes, version: release.version)
    }
}

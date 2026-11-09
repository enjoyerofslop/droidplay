import Foundation
import Testing

@testable import NXPlayKit

/// GitHub as the notify path sees it: an answer per URL, and every URL asked.
@MainActor private final class FakeGitHub {
    var answers: [URL: (body: String, status: Int)] = [:]
    var offline = false
    private(set) var asked: [URL] = []

    func answer(_ url: URL) throws -> (Data, Int) {
        asked.append(url)
        if offline { throw URLError(.notConnectedToInternet) }
        let (body, status) = answers[url] ?? ("", 404)
        return (Data(body.utf8), status)
    }

    var fetch: AppUpdater.Fetch { { url in try await self.answer(url) } }

    /// The latest release: its tag, notes and page.
    func latest(_ tag: String, notes: String = "### Fixed\n\n- **A fix.**", page: String? = nil) {
        let object: [String: Any] = [
            "tag_name": tag, "body": notes,
            "html_url": page ?? "https://github.com/enjoyerofslop/droidplay/releases/tag/\(tag)",
            "assets": [
                [
                    "name": "DroidPlay-\(tag).dmg",
                    "browser_download_url": "https://github.com/x/DroidPlay-\(tag).dmg",
                    "digest": "sha256:ABCDEF",
                ]
            ],
        ]
        let json = try! JSONSerialization.data(withJSONObject: object)
        answers[AppUpdater.latestRelease] = (String(decoding: json, as: UTF8.self), 200)
    }
}

/// A DroidPlay release signed ad hoc only says a newer release is out: it never downloads or installs it.
@MainActor @Suite struct UpdateNoticeTests {
    let root: URL
    private let github = FakeGitHub()

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(
            path: "nxplay-notice-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    private static let changelog = """
        # Changelog

        ## Unreleased

        ## 0.4.0 — 2026-11-20

        ### Added

        - **Four.**

        ## 0.3.0 — 2026-11-15

        ### Fixed

        - **Three.**

        ## 0.2.0 — 2026-11-08

        - **Two.**
        """

    /// An ad-hoc released DroidPlay of a version, asking the fake GitHub.
    private func updater(version: String = "0.2.0", mode: AppUpdater.Mode = .notify) throws
        -> AppUpdater
    {
        let app = root.appending(path: "DroidPlay-\(UUID().uuidString).app")
        let contents = app.appending(path: "Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let info: NSDictionary = [
            "CFBundleIdentifier": "io.github.enjoyerofslop.droidplay",
            "CFBundleShortVersionString": version,
        ]
        info.write(to: contents.appending(path: "Info.plist"), atomically: true)
        let bundle = try #require(Bundle(url: app))
        let updater = AppUpdater(
            bundle: bundle, folder: root.appending(path: "Updates"), mode: mode,
            fetch: github.fetch)
        updater.openPage = { _ in Issue.record("opened a page") }
        return updater
    }

    @Test func theSignatureAndTheCheckoutChooseTheMode() {
        #expect(AppUpdater.Mode(teamID: "535S292559", fromCheckout: false) == .install)
        #expect(AppUpdater.Mode(teamID: nil, fromCheckout: false) == .notify)
        #expect(AppUpdater.Mode(teamID: "535S292559", fromCheckout: true) == .off)
        #expect(AppUpdater.Mode(teamID: nil, fromCheckout: true) == .off)
    }

    @Test func comparesDroidPlaysVersions() {
        #expect(AppUpdater.isNewer("0.3.0", than: "0.2.0"))
        #expect(AppUpdater.isNewer("0.2.1", than: "0.2"))
        #expect(AppUpdater.isNewer("0.10.0", than: "0.9.9"))
        #expect(AppUpdater.isNewer("1.0", than: "0.9.9"))
        #expect(!AppUpdater.isNewer("0.2.0", than: "0.2.0"))
        #expect(!AppUpdater.isNewer("0.2", than: "0.2.0"))
        #expect(!AppUpdater.isNewer("0.1.1", than: "0.2.0"))
    }

    @Test func readsTheReleasePageWithoutADMG() throws {
        let json = #"{"tag_name": "v0.3.0", "body": "notes", "html_url": "https://github.com/a/b/releases/tag/v0.3.0"}"#
        let release = try #require(AppUpdater.ReleasePage(json: Data(json.utf8)))
        #expect(release.version == "0.3.0" && release.tag == "v0.3.0" && release.notes == "notes")
        #expect(release.page.absoluteString == "https://github.com/a/b/releases/tag/v0.3.0")
        // a page that isn't GitHub's own isn't opened: the releases list is
        for page in ["http://github.com/x", "https://example.com/x", "file:///tmp/x"] {
            let other = json.replacing("https://github.com/a/b/releases/tag/v0.3.0", with: page)
            #expect(AppUpdater.ReleasePage(json: Data(other.utf8))?.page == AppUpdater.releasesPage)
        }
        #expect(AppUpdater.ReleasePage(json: Data(#"{"body": "no tag"}"#.utf8)) == nil)
    }

    @Test func tellsOfANewerReleaseWithEveryReleaseSinceThisOne() async throws {
        let updater = try updater()
        github.latest("v0.4.0")
        let changelog = try #require(AppUpdater.changelog(at: "v0.4.0"))
        github.answers[changelog] = (Self.changelog, 200)
        #expect(updater.isEnabled)

        await updater.check()

        guard case .available(let version, let notes, let page) = updater.state else {
            Issue.record("not available: \(updater.state)")
            return
        }
        #expect(version == "0.4.0")
        #expect(notes.sections.map(\.version) == ["0.4.0", "0.3.0"])  // the skipped 0.3.0 too
        #expect(page.absoluteString == "https://github.com/enjoyerofslop/droidplay/releases/tag/v0.4.0")
        #expect(updater.notice == AppUpdater.Notice(version: "0.4.0", notes: notes, page: page))
        #expect(updater.lastCheck != nil && updater.problem == nil)
        // only the release's details and its changelog: no DMG, nothing staged
        #expect(github.asked == [AppUpdater.latestRelease, changelog])
        #expect(!FileManager.default.fileExists(atPath: root.appending(path: "Updates").path))
    }

    @Test func withoutTheChangelogTheReleaseNotesSayWhatsNew() async throws {
        let updater = try updater()
        github.latest("v0.3.0", notes: "### Fixed\n\n- **Three.**")
        await updater.check()
        guard case .available(_, let notes, _) = updater.state else {
            Issue.record("not available: \(updater.state)")
            return
        }
        #expect(notes.sections.map(\.title) == ["0.3.0"])
        #expect(notes.sections.first?.blocks == [.heading("Fixed"), .item("**Three.**")])
    }

    @Test func thisVersionOrAnOlderOneIsUpToDate() async throws {
        for tag in ["v0.2.0", "v0.1.1"] {
            let updater = try updater()
            github.latest(tag)
            await updater.check()
            #expect(updater.state == .upToDate && updater.notice == nil)
        }
    }

    @Test func aFailedCheckSaysSoUnlessANoticeIsUp() async throws {
        let updater = try updater()
        github.answers[AppUpdater.latestRelease] = ("busy", 503)
        await updater.check()
        #expect(updater.state == .failed("GitHub didn't answer"))

        github.latest("v0.3.0")
        await updater.check()
        let shown = updater.state
        #expect(updater.notice?.version == "0.3.0")
        // the next day offline, or GitHub busy: the release is still out, so its notice stays
        github.offline = true
        await updater.check()
        #expect(updater.state == shown)
        github.offline = false
        github.answers[AppUpdater.latestRelease] = ("busy", 503)
        await updater.check()
        #expect(updater.state == shown)
    }

    @Test func aNewerReleaseTakesTheNoticesPlace() async throws {
        let updater = try updater()
        github.latest("v0.3.0")
        await updater.check()
        github.latest("v0.4.0")
        await updater.check()
        #expect(updater.notice?.version == "0.4.0")
    }

    @Test func aCheckoutBuildAsksNothing() async throws {
        let updater = try updater(mode: .off)
        github.latest("v0.4.0")
        await updater.check()
        #expect(!updater.isEnabled && updater.state == .idle && github.asked.isEmpty)
    }

    @Test func theButtonOpensTheReleasePageOnly() async throws {
        let updater = try updater()
        var opened: [URL] = []
        updater.openPage = { opened.append($0) }
        updater.openReleasePage()
        #expect(opened.isEmpty)  // nothing out yet
        github.latest("v0.3.0")
        await updater.check()
        updater.openReleasePage()
        #expect(opened.map(\.absoluteString) == [
            "https://github.com/enjoyerofslop/droidplay/releases/tag/v0.3.0"
        ])
    }

    @Test func consoleModesCardOpensThePageInsteadOfRestarting() throws {
        let suite = testDefaultsName()
        defer { removeTestDefaults(suite) }
        let library = Library(defaults: UserDefaults(suiteName: suite)!, isScreenshot: true)
        var quit = false
        library.terminate = { quit = true }
        var opened: [URL] = []
        library.updater.openPage = { opened.append($0) }
        library.updater.preview(AppUpdater.PreviewKind.available)
        let notice = try #require(library.updater.notice)
        #expect(notice.page == AppUpdater.releasesPage)
        #expect(AppUpdater.isNewer(notice.version, than: library.updater.currentVersion))
        #expect(UpdateCard.subtitle(notice, library: library).hasPrefix("Out on GitHub."))

        library.handle(.menu)
        library.handle(.info)
        #expect(library.showsUpdate)
        library.handle(.confirm)
        #expect(opened == [AppUpdater.releasesPage] && !quit && !library.showsUpdate)
        #expect(!library.quitsWhenIdle)
    }
}

import Foundation
import Testing

@testable import NXPlayKit

@MainActor @Suite struct SetupTests {
    @Test func readsTheReportBySection() {
        var parser = SetupParser()
        for line in [
            "", "Mac", "  ✓ Apple silicon", "", "Tools",
            "  ✗ Homebrew is not installed: install it from https://brew.sh",
            "==> Downloading https://ghcr.io/…", "Using zstd", "", "Python (.venv)",
            "  ! uv is not installed: brew install uv", "1 problem to fix; then check again.",
        ] {
            parser.read(line)
        }
        #expect(parser.items.map(\.section) == ["Mac", "Tools", "Python"])
        #expect(parser.items.map(\.state) == [.ok, .missing, .warning])
        #expect(
            parser.items[1].text == "Homebrew is not installed: install it from https://brew.sh")
    }

    @Test func readsTheAndroidSectionsAndAsksForTheLicenseOnlyWhenNeeded() {
        var parser = SetupParser()
        for line in [
            "nxnative", "  ✓ /Users/me/nxnative (abc1234, 2 days ago)", "", "droidnative",
            "  ✗ not cloned at droidnative (Install on Android needs it): git clone …", "",
            "Android", "  ✓ JDK 21.0.5 (/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home)",
            "  ✗ Android SDK packages missing at /Users/me/Library/Android/sdk: ndk;28.2.13676358 (installing them accepts the Android SDK License: DroidPlay's Setup asks first, or run bin/setup in Terminal)",
        ] {
            parser.read(line)
        }
        #expect(parser.items.map(\.section) == ["nxnative", "droidnative", "Android", "Android"])
        #expect(parser.items.map(\.state) == [.ok, .missing, .ok, .missing])
    }

    @Test func passesTheAndroidLicenseOnlyOnceAccepted() async throws {
        let script = FileManager.default.temporaryDirectory.appending(
            path: "nxplay-setup-\(UUID().uuidString)")
        // the packages' line names the license until it is accepted, as bin/setup's does
        try Data(
            """
            echo Android
            if [ "$NXPLAY_ANDROID_LICENSES" = accept ]; then echo "  ✓ Android SDK at /sdk: ndk;28.2.13676358"; exit 0; fi
            echo "  ✗ Android SDK packages missing at /sdk: ndk;28.2.13676358 (installing them accepts the Android SDK License)"
            exit 1

            """.utf8
        ).write(to: script)
        let setup = Setup(script: script, environment: { [:] })
        func finish() async throws {
            for _ in 0..<100 where setup.phase != .idle || setup.succeeded == nil {
                try await Task.sleep(for: .milliseconds(20))
            }
        }
        setup.check()
        try await finish()
        #expect(setup.needsAndroidLicense)

        setup.install()
        try await finish()
        #expect(setup.succeeded == false && setup.needsAndroidLicense)

        setup.install(acceptingAndroidLicense: true)
        try await finish()
        #expect(setup.succeeded == true && !setup.needsAndroidLicense)
    }

    @Test func runsTheScriptAndReportsTheResult() async throws {
        let script = FileManager.default.temporaryDirectory.appending(
            path: "nxplay-setup-\(UUID().uuidString)")
        try Data(
            """
            echo
            echo Tools
            echo "  ✓ Homebrew tools (Brewfile)"
            [ "$1" = --check ] && { echo "  ✗ the Python packages are missing: uv sync --locked ($NXPLAY_HOME)"; exit 1; }
            echo "  ✓ Python with nxnative's packages"

            """.utf8
        ).write(to: script)
        let setup = Setup(script: script, environment: { ["NXPLAY_HOME": "/home"] })
        var finished = 0
        setup.onFinish = { finished += 1 }

        setup.check()
        for _ in 0..<100 where setup.succeeded == nil {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(setup.succeeded == false && finished == 1)
        #expect(
            setup.missing.map(\.text) == [
                "the Python packages are missing: uv sync --locked (/home)"
            ])

        setup.install()
        for _ in 0..<100 where setup.phase != .idle || finished < 2 {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(setup.succeeded == true)
        #expect(setup.missing.isEmpty && setup.items.count == 2)
        #expect(setup.log.lines.contains { $0.text.contains("Python with nxnative's packages") })
    }
}

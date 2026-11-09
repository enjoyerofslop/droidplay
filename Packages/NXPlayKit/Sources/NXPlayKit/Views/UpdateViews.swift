import SwiftUI

/// Above the library once an update is staged: it installs when DroidPlay quits, or now.
struct UpdateBanner: View {
    let version: String
    let notes: Changelog
    @Environment(Library.self) private var library

    var body: some View {
        HStack {
            Image(systemName: "arrow.down.circle")
            // looked at again hourly: an update waiting for days gets the warmer reminder
            TimelineView(.periodic(from: .now, by: 3600)) { context in
                Text(Self.message(version, library: library, now: context.date))
            }
            Spacer()
            WhatsNewButton(version: version, notes: notes)
            if !library.quitsWhenIdle {
                Button("Restart to Update") { library.restartToUpdate() }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.blue.opacity(0.12))
    }

    /// What the banner says: ready, still waiting after a few days (kindly), or restarting.
    static func message(_ version: String, library: Library, now: Date) -> String {
        if library.quitsWhenIdle {
            return "DroidPlay restarts with \(version) once the running game or build ends."
        }
        if let since = library.updater.waitingSince(now: now) {
            return
                "DroidPlay \(version) has been waiting since \(since.formatted(.dateTime.weekday(.wide))). Restart to Update takes a few seconds."
        }
        return "DroidPlay \(version) is ready. It installs when you quit."
    }
}

/// Above the library when a newer release is out on GitHub, for a copy that doesn't install it (signed ad hoc): its
/// page, where the player downloads it. Later hides it until the next launch, since the player may keep this version
/// for now.
struct UpdateAvailableBanner: View {
    let version: String
    let notes: Changelog
    let dismiss: () -> Void
    @Environment(Library.self) private var library

    var body: some View {
        HStack {
            Image(systemName: "arrow.down.circle")
            Text(Self.message(version))
            Spacer()
            WhatsNewButton(version: version, notes: notes)
            Button("Open Release Page") { library.updater.openReleasePage() }
            Button("Later", action: dismiss)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.blue.opacity(0.12))
    }

    static func message(_ version: String) -> String {
        "DroidPlay \(version) is out. Download it from its release page and drag it into Applications."
    }
}

/// Above the library when updates can't work for a reason the player can fix: once a launch, dismissable.
struct UpdateProblemBanner: View {
    let problem: String
    let dismiss: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
            Text("DroidPlay can't update itself from here. \(problem)")
            Spacer()
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
            }
            Button("Dismiss", action: dismiss)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.orange.opacity(0.12))
    }
}

/// Settings' Updates section.
struct UpdateSettings: View {
    @Environment(Library.self) private var library

    var body: some View {
        let updater = library.updater
        LabeledContent("Version \(updater.currentVersion)") {
            HStack {
                status(updater.state)
                switch updater.state {
                case .ready(let version, let notes):
                    WhatsNewButton(version: version, notes: notes)
                    Button("Restart to Update") { library.restartToUpdate() }
                case .available(let version, let notes, _):
                    WhatsNewButton(version: version, notes: notes)
                    Button("Open Release Page") { updater.openReleasePage() }
                case .checking, .downloading: EmptyView()
                default: Button("Check Now") { Task { await updater.check() } }
                }
            }
        }
        .disabled(!updater.isEnabled)
    }

    /// What the copy does about new releases, under the section.
    static func footer(_ mode: AppUpdater.Mode) -> String {
        switch mode {
        case .install:
            "DroidPlay looks for a new release on GitHub at launch and once a day, and downloads it. It installs when you quit, or now with Restart to Update."
        case .notify:
            "DroidPlay looks for a new release on GitHub at launch and once a day, and says when one is out. It doesn't update itself: download the new release from its page and drag it into Applications."
        case .off:
            "This copy was built from the source: update it with git pull and bin/install."
        }
    }

    @ViewBuilder private func status(_ state: AppUpdater.State) -> some View {
        switch state {
        case .idle: EmptyView()
        case .checking: ProgressView().controlSize(.small)
        case .upToDate: Text("Up to date").foregroundStyle(.secondary)
        case .downloading(let version):
            ProgressView().controlSize(.small)
            Text("Downloading \(version)…").foregroundStyle(.secondary)
        case .ready(let version, _): Text("\(version) is ready").foregroundStyle(.secondary)
        case .available(let version, _, _): Text("\(version) is out").foregroundStyle(.secondary)
        case .failed(let message): Text(message).foregroundStyle(.orange).lineLimit(2)
        }
    }
}

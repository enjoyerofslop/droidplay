import AppKit
import SwiftUI

/// What the builds need, checked when the window opens, and one button that installs what's missing. Homebrew is the
/// one step the player takes in Terminal; everything else installs from here.
public struct SetupView: View {
    public static let windowID = "setup"

    @Environment(Library.self) private var library
    @State private var setup: Setup?
    @State private var showsLog = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Setup").font(.title2.bold())
            Text(
                "Switch games build with Xcode, a few Homebrew tools, Python and nxnative; for Android, with droidnative, a JDK and the Android SDK. DroidPlay installs all but Xcode and Homebrew itself, and keeps what it installs in one folder, except the Android SDK, which goes where Android Studio keeps it."
            )
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            if let setup {
                SetupItems(setup: setup)
                if setup.homebrewMissing { HomebrewStep() }
                if showsLog {
                    LogTextView(jobID: logID, log: setup.log)
                        .frame(minHeight: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                footer(setup)
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .frame(width: 640)
        .frame(minHeight: 420)
        .task {
            if setup == nil {
                let setup = Setup(library: library)
                setup.onFinish = { [library] in library.refresh() }
                self.setup = setup
                setup.check()
            }
        }
    }

    @State private var logID = UUID()
    @State private var asksAndroidLicense = false
    static let androidLicense = URL(string: "https://developer.android.com/studio/terms")!

    private func install(_ setup: Setup, acceptingAndroidLicense: Bool = false) {
        showsLog = true
        logID = UUID()
        setup.install(acceptingAndroidLicense: acceptingAndroidLicense)
    }

    @ViewBuilder private func footer(_ setup: Setup) -> some View {
        HStack {
            Toggle("Show Details", isOn: $showsLog).toggleStyle(.checkbox)
            Button("Open Folder") { NSWorkspace.shared.open(AppHome.folder) }
                .disabled(!FileManager.default.fileExists(atPath: AppHome.folder.path))
                .help(AppHome.folder.path)
            Spacer()
            switch setup.phase {
            case .checking:
                ProgressView().controlSize(.small)
                Text("Checking…").foregroundStyle(.secondary)
            case .installing:
                ProgressView().controlSize(.small)
                Text("Installing…").foregroundStyle(.secondary)
                Button("Stop") { setup.stop() }
            case .idle:
                Button("Check Again") { setup.check() }
                Button("Install Missing") {
                    if setup.needsAndroidLicense { asksAndroidLicense = true } else { install(setup) }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(setup.missing.isEmpty || setup.homebrewMissing)
            }
        }
        // sdkmanager installs the Android SDK's packages only under a license someone accepted; the player does, here
        .alert("Install the Android SDK?", isPresented: $asksAndroidLicense) {
            Button("Accept and Install") { install(setup, acceptingAndroidLicense: true) }
            Button("Read the License") { NSWorkspace.shared.open(Self.androidLicense) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Install on Android needs Google's Android SDK: the NDK, CMake, build-tools, an Android platform and platform-tools, about 3 GB in ~/Library/Android/sdk. Installing them means you accept the Android Software Development Kit License Agreement."
            )
        }
    }
}

/// The report, by section.
private struct SetupItems: View {
    let setup: Setup

    var body: some View {
        let sections = setup.items.reduce(into: [String]()) {
            if !$0.contains($1.section) { $0.append($1.section) }
        }
        ScrollView {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 6) {
                ForEach(sections, id: \.self) { section in
                    GridRow {
                        Text(section).font(.headline).gridCellColumns(2)
                    }
                    .padding(.top, 6)
                    ForEach(setup.items.filter { $0.section == section }) { item in
                        GridRow {
                            mark(item.state)
                            Text(item.text).textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 220)
    }

    private func mark(_ state: Setup.Item.State) -> some View {
        switch state {
        case .ok: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .warning: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        case .missing: Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        }
    }
}

/// Homebrew installs from Terminal (it asks for the password and explains itself there); this copies the command.
private struct HomebrewStep: View {
    static let command =
        #"/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)""#
    @State private var copied = false

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text(
                    "Install Homebrew first: paste this into Terminal, follow its steps, then Check Again."
                )
                Text(Self.command).font(.caption.monospaced()).textSelection(.enabled)
                HStack {
                    Button(copied ? "Copied" : "Copy Command") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(Self.command, forType: .string)
                        copied = true
                    }
                    Button("Open Terminal") {
                        NSWorkspace.shared.open(
                            URL(filePath: "/System/Applications/Utilities/Terminal.app"))
                    }
                    Link("brew.sh", destination: URL(string: "https://brew.sh")!)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Above the library until setup is complete.
struct SetupBanner: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack {
            Image(systemName: "wrench.and.screwdriver")
            Text("DroidPlay needs a few tools before it can build games.")
            Spacer()
            Button("Open Setup") { openWindow(id: SetupView.windowID) }
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.orange.opacity(0.15))
    }
}

/// DroidPlay › Setup… and the Settings button.
public struct SetupMenuItem: View {
    @Environment(\.openWindow) private var openWindow

    public init() {}

    public var body: some View {
        Button("Setup…") { openWindow(id: SetupView.windowID) }
    }
}

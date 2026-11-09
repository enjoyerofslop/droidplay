import Foundation

/// A checkout build never updates itself, so its update notices can't be seen. Launched with
/// `-NXPlayPreviewUpdate ready|waiting|problem|available`, it fakes one instead, with the changelog's Unreleased notes:
///
///     open -a "DroidPlay" --args -NXPlayPreviewUpdate waiting
///
/// Released apps ignore it. Restart to Update just quits: nothing is installed. `available` is an ad-hoc release's
/// notice, whose button opens GitHub's releases page.
extension AppUpdater {
    enum PreviewKind: String, CaseIterable {
        /// Just downloaded.
        case ready
        /// Ready for days: the warmer reminder.
        case waiting
        /// Run from somewhere it can't replace itself.
        case problem
        /// Out on GitHub, for a release signed ad hoc, which only tells about it.
        case available
    }

    /// The preview the launch asked for, in a checkout build only.
    static var requestedPreview: PreviewKind? {
        guard AppHome.sourceRoot != nil else { return nil }
        return UserDefaults.standard.string(forKey: "NXPlayPreviewUpdate").flatMap(
            PreviewKind.init(rawValue:))
    }

    func preview(_ kind: PreviewKind, now: Date = .now) {
        switch kind {
        case .ready, .waiting:
            preview(
                .ready(version: nextVersion, notes: unreleasedNotes),
                readySince: kind == .waiting ? now.addingTimeInterval(-4 * 86_400) : now)
        case .available:
            preview(
                .available(version: nextVersion, notes: unreleasedNotes, page: Self.releasesPage))
        case .problem:
            preview(.failed(Self.moveToApplications), problem: Self.moveToApplications)
        }
    }

    private var nextVersion: String { Self.nextVersion(after: currentVersion) }

    /// The changelog's Unreleased notes, as the next version's.
    private var unreleasedNotes: Changelog {
        let unreleased = Changelog.bundled?.sections.first { $0.version == nil }
        return Changelog(
            sections: unreleased.map { [Changelog.Section(title: nextVersion, blocks: $0.blocks)] }
                ?? [])
    }

    /// "1.7.10" after "1.7.9": a version that reads as newer.
    static func nextVersion(after version: String) -> String {
        var parts = version.split(separator: ".").map { Int($0) ?? 0 }
        if parts.isEmpty { parts = [0] }
        parts[parts.count - 1] += 1
        return parts.map(String.init).joined(separator: ".")
    }
}

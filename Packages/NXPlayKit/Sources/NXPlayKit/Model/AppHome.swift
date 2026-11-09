import Foundation

/// Where DroidPlay keeps what it installs, in one folder: `~/Library/Application Support/DroidPlay` holds the nxnative
/// checkout, the Python environment and the Python uv installs for it, and uv's cache. Homebrew's tools are the only
/// other thing setup installs. A complete uninstall removes this folder; the games folder is the player's.
///
/// A build from a checkout (bin/build, bin/install) keeps using the checkout's .venv and ./nxnative or ../nxnative, as
/// bin/setup made them; bin/release leaves the checkout out (NX_SOURCE_ROOT empty), so a released app always uses
/// its own folder, on the developer's Mac too.
public enum AppHome {
    public static var folder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "DroidPlay", directoryHint: .isDirectory)
    }

    /// The checkout the app was built from, when it still exists; nil for a released app.
    static var sourceRoot: URL? {
        guard let path = Bundle.main.object(forInfoDictionaryKey: "NXSourceRoot") as? String,
            !path.isEmpty, !path.contains("$("),
            FileManager.default.fileExists(atPath: path + "/nxplay")
        else { return nil }
        return URL(filePath: path, directoryHint: .isDirectory)
    }

    /// nxnative: the checkout's (./nxnative, else ../nxnative, where bin/setup and nxplay look), else our own.
    public static var defaultNXNative: String {
        if let sourceRoot {
            let inside = sourceRoot.appending(path: "nxnative")
            return FileManager.default.fileExists(atPath: inside.path)
                ? inside.path
                : sourceRoot.deletingLastPathComponent().appending(path: "nxnative").path
        }
        return folder.appending(path: "nxnative").path
    }

    /// DroidPlay Core, for Install on Android, where nxplay looks for it: beside nxnative for a build from a checkout
    /// (./droidplay-core, else ../droidplay-core), else in our own folder. A checkout cloned before a rename keeps its
    /// folder (droidnative until 2026-11-09, nxnative-android before that), found when there is no droidplay-core one.
    public static var defaultNXNativeAndroid: String {
        let fm = FileManager.default
        func pick(_ dir: URL) -> URL? {
            for name in ["droidplay-core", "droidnative", "nxnative-android"] {
                let url = dir.appending(path: name)
                if fm.fileExists(atPath: url.path) { return url }
            }
            return nil
        }
        if let sourceRoot {
            return (pick(sourceRoot) ?? pick(sourceRoot.deletingLastPathComponent())
                ?? sourceRoot.deletingLastPathComponent().appending(path: "droidplay-core")).path
        }
        return (pick(folder) ?? folder.appending(path: "droidplay-core")).path
    }

    /// The Python environment nxnative's scripts run in.
    public static var venv: URL {
        sourceRoot?.appending(path: ".venv", directoryHint: .isDirectory)
            ?? folder.appending(path: "venv", directoryHint: .isDirectory)
    }

    /// Whether the Python environment has the packages this DroidPlay's uv.lock asks for: bin/setup keeps a copy of the
    /// lock it last synced to in the environment, so an update that adds a package (zbic) asks for Setup once, rather
    /// than a build failing on the import.
    static var venvIsCurrent: Bool {
        guard let lock = (setupProject ?? sourceRoot)?.appending(path: "uv.lock"),
            let wanted = try? Data(contentsOf: lock)
        else { return true }
        return (try? Data(contentsOf: venv.appending(path: "nxplay-uv.lock"))) == wanted
    }

    /// nxplay, from the bundle (or the checkout, for tests run from it).
    static var script: URL? {
        Bundle.main.url(forResource: "nxplay", withExtension: nil)
            ?? sourceRoot?.appending(path: "nxplay")
    }

    /// The setup the app runs (bin/setup with the Brewfile, pyproject.toml and uv.lock it reads), bundled in
    /// Resources/Setup.
    static var setupProject: URL? {
        Bundle.main.resourceURL?.appending(path: "Setup", directoryHint: .isDirectory)
            .nilIfMissing(child: "setup")
    }
}

extension URL {
    fileprivate func nilIfMissing(child: String) -> URL? {
        FileManager.default.fileExists(atPath: appending(path: child).path) ? self : nil
    }
}

import Foundation

/// Where NX Play keeps what it installs, in one folder: `~/Library/Application Support/NX Play` holds the nxnative
/// checkout, the Python environment and the Python uv installs for it, and uv's cache. Homebrew's tools are the only
/// other thing setup installs. A complete uninstall removes this folder; the games folder is the player's.
///
/// A build from a checkout (bin/build, bin/install) keeps using the checkout's .venv and ./nxnative or ../nxnative, as
/// bin/setup made them; bin/release leaves the checkout out (NX_SOURCE_ROOT empty), so a released app always uses
/// its own folder, on the developer's Mac too.
public enum AppHome {
    public static var folder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "NX Play", directoryHint: .isDirectory)
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

    /// nxnative-android, for Install on Android, where nxplay looks for it: beside nxnative for a build from a checkout
    /// (./nxnative-android, else ../nxnative-android), else in our own folder.
    public static var defaultNXNativeAndroid: String {
        if let sourceRoot {
            let inside = sourceRoot.appending(path: "nxnative-android")
            return FileManager.default.fileExists(atPath: inside.path)
                ? inside.path
                : sourceRoot.deletingLastPathComponent().appending(path: "nxnative-android").path
        }
        return folder.appending(path: "nxnative-android").path
    }

    /// The Python environment nxnative's scripts run in.
    public static var venv: URL {
        sourceRoot?.appending(path: ".venv", directoryHint: .isDirectory)
            ?? folder.appending(path: "venv", directoryHint: .isDirectory)
    }

    /// Whether the Python environment has the packages this NX Play's uv.lock asks for: bin/setup keeps a copy of the
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

import Foundation

/// Install on Android: nxnative-android, the fork of nxnative that carries its Android port (seedds/nxnative stays
/// Apple-only), builds the game in `<game folder>/android` and installs it on a device with adb, then starts it
/// there (nxplay --android). It has a checkout of its own, set in Settings › Devices, which can be a developer's
/// checkout of a branch: nxplay follows its upstream, and stays on a branch that has none.
extension Library {
    /// The marker of an nxnative-android checkout, which Settings and the command check.
    nonisolated static let androidScript = "scripts/build_android_from_nsp.py"

    /// The checkout Install on Android builds with, ~ expanded.
    var nxnativeAndroidRepo: String { (nxnativeAndroidPath as NSString).expandingTildeInPath }

    public func installOnAndroid(_ game: Game, on device: AndroidDevice) {
        run(.android(device), game)
    }

    /// Build APK: the app and the game's files in `<game folder>/android/<game name> (Android)`, to copy to any device.
    public func buildAPK(_ game: Game) { run(.apk, game) }

    /// The devices whose app has this game, which Play on Android can start it on.
    public func androidDevices(with game: Game) -> [AndroidDevice] {
        guard let id = game.titleID?.uppercased() else { return [] }
        return androidDevices.filter { $0.games.contains(id) }
    }

    /// Starts the game on the device, as installed there last; nothing is built or copied.
    public func playOnAndroid(_ game: Game, on device: AndroidDevice) {
        guard let id = game.titleID else { return }
        Task {
            if let failure = await AndroidDevice.launch(titleID: id, on: device.id) {
                problem = "Couldn't start \(game.name) on \(device.name): \(failure)"
            }
        }
    }

    /// The devices adb sees; with Xcode's, on launch, on activation and after an install.
    func refreshAndroidDevices() {
        guard !isScreenshot, !isLoadingAndroidDevices else { return }
        isLoadingAndroidDevices = true
        Task {
            androidDevices = await AndroidDevice.load()
            isLoadingAndroidDevices = false
        }
    }

    /// nxplay --android's or --apk's command. The prod.keys were checked with the other kinds'; the Mac's nxnative
    /// checkout isn't needed, as nxplay builds with nxnative-android's (NXNATIVE_ANDROID).
    func androidCommand(
        _ kind: Job.Kind, _ game: Game, script: URL, keys: String, lang: [String]
    ) -> NXPlayCommand? {
        let repo = nxnativeAndroidRepo
        guard FileManager.default.fileExists(atPath: repo + "/" + Self.androidScript) else {
            problem = """
                No nxnative-android checkout at \(repo). Clone https://github.com/RogelioLB/nxnative-android \
                there, or set its folder in Settings › Devices.
                """
            return nil
        }
        var environment = NXPlayCommand.environment(
            nxnative: nxnativeRepo(for: game), keys: keys, venv: AppHome.venv.path)
        environment["NXNATIVE_ANDROID"] = repo
        return NXPlayCommand(
            script: script,
            arguments: Self.androidArguments(kind, lang: lang, folder: game.folder),
            environment: environment)
    }

    /// `--android <serial>` installs on the device; `--apk` exports instead.
    nonisolated static func androidArguments(_ kind: Job.Kind, lang: [String], folder: URL) -> [String] {
        let target = if case .android(let device) = kind { ["--android", device.id] } else { ["--apk"] }
        return target + lang + [folder.path]
    }
}

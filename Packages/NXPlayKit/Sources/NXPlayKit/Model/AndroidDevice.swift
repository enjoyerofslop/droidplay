import Foundation

/// An Android device a game can be installed on through adb (Install on Android): connected, with USB debugging
/// allowed for this Mac. nxnative-android's one app carries every game built on this Mac; `games` are the ones it
/// has on the device.
public struct AndroidDevice: Hashable, Identifiable, Sendable {
    /// The serial adb takes (`adb -s`).
    public let id: String
    /// The name the device was given (Settings › About), else its model.
    public let name: String
    public let model: String
    /// The title IDs the app has on the device, uppercased: its `files/games/<title ID>` folders.
    public var games: Set<String> = []

    /// nxnative-android's app, and where it keeps each game (build_android_from_nsp.py's PKG and REMOTE).
    static let package = "org.nxnative.android"
    static let gamesFolder = "/sdcard/Android/data/\(package)/files/games"

    /// The ready devices in `adb devices -l` output, named by their model until load() asks for their names. One
    /// waiting for its player to allow USB debugging (unauthorized) or offline can't take an install.
    public static func parse(devicesList output: String) -> [AndroidDevice] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            let words = line.split(whereSeparator: \.isWhitespace).map(String.init)
            guard words.count >= 2, words[1] == "device" else { return nil }
            let model =
                words.first { $0.hasPrefix("model:") }.map {
                    $0.dropFirst("model:".count).replacingOccurrences(of: "_", with: " ")
                } ?? words[0]
            return AndroidDevice(id: words[0], name: model, model: model)
        }
    }

    /// The title IDs in a listing of the app's games folder; anything else in it (a stray file) isn't a game.
    static func parse(gamesListing output: String) -> Set<String> {
        Set(
            output.split(whereSeparator: \.isWhitespace).map { $0.uppercased() }.filter {
                $0.count == 16 && $0.allSatisfy(\.isHexDigit)
            })
    }

    /// adb: the Android SDK's (ANDROID_HOME, else Android Studio's default place), else Homebrew's. A Mac app started
    /// from Finder has none of them on PATH.
    nonisolated static func adb(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: String = NSHomeDirectory()
    ) -> URL? {
        let sdks = [environment["ANDROID_HOME"], environment["ANDROID_SDK_ROOT"]].compactMap { $0 }
            + ["\(home)/Library/Android/sdk"]
        return (sdks.map { "\($0)/platform-tools/adb" } + ["/opt/homebrew/bin/adb", "/usr/local/bin/adb"])
            .first { FileManager.default.isExecutableFile(atPath: $0) }
            .map { URL(filePath: $0) }
    }

    /// Asks adb for the ready devices, their names and their games, off the main thread.
    public static func load() async -> [AndroidDevice] {
        await Task.detached {
            guard let adb = adb() else { return [] }
            // the server on its own first: started by `devices`, the daemon would keep the pipe open and the read wait
            _ = run(adb, ["start-server"], output: false)
            return parse(devicesList: run(adb, ["devices", "-l"]) ?? "").map { device in
                var device = device
                let given = run(adb, ["-s", device.id, "shell", "settings", "get", "global", "device_name"])?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !given.isEmpty, given != "null" {
                    device = AndroidDevice(id: device.id, name: given, model: device.model)
                }
                device.games = parse(
                    gamesListing: run(adb, ["-s", device.id, "shell", "ls", gamesFolder]) ?? "")
                return device
            }
        }.value
    }

    /// Starts a game the app has on the device, the way nxplay --android does after an install; the failure's words,
    /// or nil when it started.
    public static func launch(titleID: String, on serial: String) async -> String? {
        await Task.detached {
            guard let adb = adb() else { return "adb isn't installed (the Android SDK's platform-tools)" }
            let said = run(adb, [
                "-s", serial, "shell", "am", "start", "-n", "\(package)/.Launcher",
                "--es", "game", titleID.uppercased(), "--ez", "play", "true",
            ])
            // am says why on stdout and still exits 0 on older Android
            guard let said else { return "adb couldn't reach the device" }
            return said.contains("Error") ? said.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        }.value
    }

    /// adb's output (stdout and stderr), nil when it couldn't run or failed.
    nonisolated private static func run(_ adb: URL, _ arguments: [String], output: Bool = true) -> String? {
        let process = Process()
        process.executableURL = adb
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        let pipe = Pipe()
        process.standardOutput = output ? pipe : FileHandle.nullDevice
        process.standardError = output ? pipe : FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let data = output ? pipe.fileHandleForReading.readDataToEndOfFile() : Data()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return String(decoding: data, as: UTF8.self)
    }
}

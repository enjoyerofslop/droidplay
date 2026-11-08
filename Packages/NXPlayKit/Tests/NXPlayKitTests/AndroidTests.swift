import Foundation
import Testing

@testable import NXPlayKit

@Suite struct AndroidTests {
    @Test func keepsReadyDevicesNamedByModel() {
        let output = """
            List of devices attached
            4839ed0d               device usb:35651584X product:kalama model:Odin2 device:kalama transport_id:1
            R5CT1234567            unauthorized usb:1-1 transport_id:2
            192.168.1.20:5555      offline transport_id:3
            emulator-5554          device product:sdk_gphone64_arm64 model:sdk_gphone64_arm64 device:emu64a transport_id:4
            0123456789ABCDEF       device transport_id:5

            """

        let devices = AndroidDevice.parse(devicesList: output)

        #expect(devices.map(\.id) == ["4839ed0d", "emulator-5554", "0123456789ABCDEF"])
        #expect(devices[0] == AndroidDevice(id: "4839ed0d", name: "Odin2", model: "Odin2"))
        #expect(devices[1].model == "sdk gphone64 arm64")
        // no model: the serial names it
        #expect(devices[2].name == "0123456789ABCDEF")
    }

    @Test func readsTheGamesTheAppHas() {
        let listing = "0100000011D90000\n01007ef00011e000\nlog.txt\n0100000011D9000\n"
        #expect(
            AndroidDevice.parse(gamesListing: listing) == ["0100000011D90000", "01007EF00011E000"])
        #expect(AndroidDevice.parse(gamesListing: "ls: /sdcard/…: No such file or directory").isEmpty)
    }

    @Test func installsOrExportsThroughNxplay() {
        let folder = URL(filePath: "/Games/Brilliant Diamond", directoryHint: .isDirectory)
        let odin = AndroidDevice(id: "4839ed0d", name: "Odin 2", model: "Odin2")
        #expect(
            Library.androidArguments(.android(odin), lang: ["--lang", "fr"], folder: folder)
                == ["--android", "4839ed0d", "--lang", "fr", "/Games/Brilliant Diamond"])
        #expect(
            Library.androidArguments(.apk, lang: [], folder: folder)
                == ["--apk", "/Games/Brilliant Diamond"])
        #expect(
            Library.androidArguments(.gameApp(.apk), lang: ["--lang", "ja"], folder: folder)
                == ["--game-apk", "--lang", "ja", "/Games/Brilliant Diamond"])
        #expect(
            Library.androidArguments(.gameApp(.xapk), lang: [], folder: folder)
                == ["--game-xapk", "/Games/Brilliant Diamond"])
    }

    @Test func doesNotTouchTheMacBuild() {
        let odin = AndroidDevice(id: "4839ed0d", name: "Odin 2", model: "Odin2")
        for kind in [Job.Kind.android(odin), .apk, .gameApp(.apk), .gameApp(.xapk)] {
            #expect(kind.buildsForAndroid)
            #expect(!kind.rewritesTheMacBuild)
        }
        #expect(!Job.Kind.ipa.buildsForAndroid)
    }

    @Test func findsTheExportedAPKAndTheGameApp() throws {
        let folder = FileManager.default.temporaryDirectory.appending(
            path: "nxplay-apk-\(UUID().uuidString)/Game", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        for path in [
            "Game [0100000011D90000][v0].nsp", "android/Game (Android)/nxnative.apk",
            // no app in it: not an export
            "android/Other (Android)/games/x",
            "android/Game.apk", "android/Game.romfs",
        ] {
            let url = folder.appending(path: path)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data([1]).write(to: url)
        }

        let game = try #require(GameScanner.game(at: folder))

        #expect(game.androidExportURL?.lastPathComponent == "Game (Android)")
        #expect(game.androidExportURL?.deletingLastPathComponent().lastPathComponent == "android")
        // the game's own app, not the nxnative app's APK inside the export folder
        #expect(game.androidAppURL?.lastPathComponent == "Game.apk")
    }

    @MainActor @Test func playOnAndroidListsTheDevicesWithTheGame() throws {
        let suite = testDefaultsName()
        defer { removeTestDefaults(suite) }
        let library = Library(defaults: try #require(UserDefaults(suiteName: suite)), isScreenshot: true)
        library.androidDevices = [
            AndroidDevice(id: "a", name: "Odin 2", model: "Odin2", games: ["0100000011D90000"]),
            AndroidDevice(id: "b", name: "Pixel", model: "Pixel 9", games: []),
        ]
        let game = Game(
            folder: URL(filePath: "/Games/BD"), name: "BD", titleID: "0100000011d90000",
            version: nil, languages: [], iconURL: nil, buildFolder: nil, ipaURL: nil,
            xcodeBuildFolder: nil, hasPackages: true, state: .ready)

        #expect(library.androidDevices(with: game).map(\.id) == ["a"])
    }
}

import SwiftUI

/// Settings › Devices › Android: the droidnative checkout Install on Android builds with, and the devices adb sees
/// (Library+Android.swift).
struct AndroidSettingsSection: View {
    @Environment(Library.self) private var library

    var body: some View {
        @Bindable var library = library
        Section {
            PathField(
                title: "droidnative repository",
                path: $library.nxnativeAndroidPath,
                directory: true,
                isValid: exists(library.nxnativeAndroidPath, Library.androidScript)
            )
            LabeledContent("Devices") {
                HStack {
                    Text(
                        library.androidDevices.isEmpty
                            ? library.isLoadingAndroidDevices ? "Looking…" : "None connected"
                            : library.androidDevices.map(\.name).joined(separator: ", ")
                    )
                    .foregroundStyle(.secondary)
                    Button("Look Again") { library.refreshDevices() }
                }
            }
        } header: {
            Text("Android")
        } footer: {
            Footer(
                "Install on Android builds a game with droidnative, a fork of nxnative with an Android port (Vulkan), in the game folder's android folder, then installs it with adb and starts it on a device with USB debugging on. One app on the device carries every game built on this Mac; its saves stay through updates. It needs the Android SDK (ANDROID_HOME, else ~/Library/Android/sdk) with an NDK, CMake and build-tools 36, and a JDK (Homebrew's openjdk works). nxplay follows the checkout's upstream before each install, and stays put on a branch without one."
            )
        }
    }
}

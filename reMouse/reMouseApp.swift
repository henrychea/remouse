import AppKit
import SwiftUI

@main
struct ReMouseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @AppStorage(SettingsKeys.showMenuBarIcon) private var showMenuBarIcon = true
    @AppStorage(SettingsKeys.invertEnabled) private var invertEnabled = true

    var body: some Scene {
        MenuBarExtra(isInserted: $showMenuBarIcon) {
            MenuDropdownView()
        } label: {
            Image(invertEnabled ? "MenuBarIcon" : "MenuBarIconOff")
                .renderingMode(.template)
                .accessibilityLabel("re:Mouse")
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DotoFont.register()

        let defaults = UserDefaults.standard
        DockVisibility.apply(defaults.bool(forKey: SettingsKeys.showInDock))
        ScrollTap.shared.isEnabled = defaults.object(forKey: SettingsKeys.invertEnabled) as? Bool ?? true
        ConflictStore.shared.refresh()

        startTapFlow()
        MainWindow.show()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        MainWindow.show()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        ScrollTap.shared.stop()
    }

    private func installTap() {
        ScrollTap.shared.install()
        ConflictStore.shared.refresh()
    }

    private func startTapFlow() {
        if !AccessibilityPermission.isTrusted {
            AccessibilityPermission.prompt()
        }

        Task { @MainActor in
            for _ in 0..<3600 {
                if PermissionState.current.isGranted { break }
                try? await Task.sleep(for: .seconds(1))
            }
            installTap()
        }
    }
}

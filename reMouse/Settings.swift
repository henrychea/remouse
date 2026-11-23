import AppKit
import CoreText
import Foundation
import ServiceManagement

enum SettingsKeys {
    static let invertEnabled = "invertEnabled"
    static let showMenuBarIcon = "showMenuBarIcon"
    static let showInDock = "showInDock"
    static let launchAtLogin = "launchAtLogin"
}

enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("re:Mouse login item failed: %@", error.localizedDescription)
        }
    }
}

@MainActor
enum DockVisibility {
    static func apply(_ visible: Bool) {
        _ = NSApp.setActivationPolicy(visible ? .regular : .accessory)
    }
}

@MainActor
enum InvertState {
    static func apply(_ enabled: Bool) {
        ScrollTap.shared.isEnabled = enabled
        if enabled {
            ConflictStore.shared.refresh()
        }
    }
}

enum DotoFont {
    static func register() {
        guard let url = Bundle.main.url(forResource: "Doto", withExtension: "ttf") else { return }
        _ = CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}

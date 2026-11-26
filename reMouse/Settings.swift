import AppKit
import CoreText
import Foundation
import ServiceManagement

enum SettingsKeys {
    static let invertEnabled = "invertEnabled"
    static let showMenuBarIcon = "showMenuBarIcon"
    static let showInDock = "showInDock"
    static let launchAtLogin = "launchAtLogin"
    static let smoothScroll = "smoothScroll"
    static let commandZoom = "commandZoom"
    static let smoothScrollExcluded = "smoothScrollExcluded"
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

@MainActor
enum SmoothState {
    static func apply(_ enabled: Bool) {
        ScrollTap.shared.isSmoothEnabled = enabled
        if !enabled {
            SmoothScroll.shared.stop()
        }
    }

    static func applyExcluded(_ bundleIDs: [String]) {
        ScrollTap.shared.smoothExcludedBundleIDs = Set(bundleIDs)
        SmoothScroll.shared.stop()
    }
}

@MainActor
enum ZoomState {
    static func apply(_ enabled: Bool) {
        ScrollTap.shared.isCommandZoomEnabled = enabled
    }
}

enum FrontmostApp {
    static func start() {
        update(NSWorkspace.shared.frontmostApplication)
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            update(notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)
        }
    }

    private static func update(_ app: NSRunningApplication?) {
        ScrollTap.shared.setFrontmost(app?.bundleIdentifier)
    }
}

enum DotoFont {
    static func register() {
        guard let url = Bundle.main.url(forResource: "Doto", withExtension: "ttf") else { return }
        _ = CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}

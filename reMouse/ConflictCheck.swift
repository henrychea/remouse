import AppKit

struct Conflict: Identifiable {
    let id = UUID()
    let name: String
    let app: NSRunningApplication?
}

enum ConflictChecker {
    static let knownBundleIDs: [String: String] = [
        "com.lujjjh.LinearMouse": "LinearMouse",
        "com.pilotmoon.scroll-reverser": "Scroll Reverser",
        "com.nuebling.mac-mouse-fix": "Mac Mouse Fix",
        "com.nuebling.mac-mouse-fix.helper": "Mac Mouse Fix Helper",
        "com.caldis.Mos": "Mos",
        "com.theron.UnnaturalScrollWheels": "UnnaturalScrollWheels",
    ]

    static func runningConflicts() -> [Conflict] {
        let running = NSWorkspace.shared.runningApplications
        return knownBundleIDs.sorted { $0.value < $1.value }.compactMap { bundleID, name in
            running.first { $0.bundleIdentifier == bundleID }.map { Conflict(name: name, app: $0) }
        }
    }
}

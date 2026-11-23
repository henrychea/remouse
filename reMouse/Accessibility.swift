import ApplicationServices

enum AccessibilityPermission {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func prompt() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}

enum PermissionState: Equatable {
    case granted
    case accessibility

    var isGranted: Bool { self == .granted }

    static var current: PermissionState {
        AccessibilityPermission.isTrusted ? .granted : .accessibility
    }
}

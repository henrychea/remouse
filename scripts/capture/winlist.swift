import CoreGraphics
import Foundation

let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { exit(1) }

for window in windows {
    let owner = window[kCGWindowOwnerName as String] as? String ?? "?"
    let pid = window[kCGWindowOwnerPID as String] as? Int ?? 0
    let title = window[kCGWindowName as String] as? String ?? ""
    let number = window[kCGWindowNumber as String] as? Int ?? 0
    let layer = window[kCGWindowLayer as String] as? Int ?? 0
    let bounds = window[kCGWindowBounds as String] as? [String: Any] ?? [:]
    let box = "\(bounds["X"] ?? 0),\(bounds["Y"] ?? 0) \(bounds["Width"] ?? 0)x\(bounds["Height"] ?? 0)"
    print("\(number)\tlayer=\(layer)\t\(owner)\t\(title)\t\(box)\t\(pid)")
}

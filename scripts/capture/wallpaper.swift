import AppKit
import Foundation

let workspace = NSWorkspace.shared
let arguments = CommandLine.arguments

func setImage(_ url: URL, _ screen: NSScreen, _ options: [NSWorkspace.DesktopImageOptionKey: Any]) -> Bool {
    do {
        try workspace.setDesktopImageURL(url, for: screen, options: options)
        return true
    } catch {
        print("wallpaper error: \(error.localizedDescription)")
        return false
    }
}

func snapshot() -> [[String: Any]] {
    NSScreen.screens.map { screen in
        let url = workspace.desktopImageURL(for: screen)
        let options = workspace.desktopImageOptions(for: screen) ?? [:]
        let scaling = (options[.imageScaling] as? NSNumber)?.intValue ?? 0
        let clipping = (options[.allowClipping] as? NSNumber)?.boolValue ?? false
        return [
            "name": screen.localizedName,
            "url": url?.path ?? "",
            "scaling": scaling,
            "clipping": clipping,
        ]
    }
}

func apply(_ entries: [[String: Any]]) {
    for (index, screen) in NSScreen.screens.enumerated() where index < entries.count {
        let entry = entries[index]
        guard let path = entry["url"] as? String, !path.isEmpty else { continue }
        let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
            .imageScaling: NSNumber(value: entry["scaling"] as? Int ?? 0),
            .allowClipping: NSNumber(value: entry["clipping"] as? Bool ?? false),
        ]
        if setImage(URL(fileURLWithPath: path), screen, options) {
            print("restored \(screen.localizedName) -> \(path)")
        }
    }
}

guard arguments.count >= 2 else {
    print("usage: wallpaper save|restore <file> | wallpaper solid <png> [displayIndex]")
    exit(1)
}

switch arguments[1] {
case "save":
    let entries = snapshot()
    let data = (try? JSONSerialization.data(withJSONObject: entries, options: [.prettyPrinted])) ?? Data()
    do {
        try data.write(to: URL(fileURLWithPath: arguments[2]))
    } catch {
        print("cannot write \(arguments[2])")
        exit(2)
    }
    print(String(data: data, encoding: .utf8) ?? "")
case "restore":
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: arguments[2])),
          let entries = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else {
        print("cannot read \(arguments[2])")
        exit(2)
    }
    apply(entries)
case "solid":
    let file = URL(fileURLWithPath: arguments[2])
    let index = arguments.count > 3 ? Int(arguments[3]) ?? -1 : -1
    for (position, screen) in NSScreen.screens.enumerated() where index < 0 || position == index {
        let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
            .imageScaling: NSNumber(value: NSImageScaling.scaleAxesIndependently.rawValue),
            .allowClipping: NSNumber(value: true),
        ]
        guard setImage(file, screen, options) else { exit(3) }
        print("set \(screen.localizedName) -> \(file.lastPathComponent)")
    }
default:
    print("unknown command")
    exit(1)
}

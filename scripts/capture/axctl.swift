import ApplicationServices
import CoreGraphics
import Foundation

func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
    var value: AnyObject?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}

func text(_ element: AXUIElement, _ name: String) -> String {
    if let string = attribute(element, name) as? String { return string }
    if let number = attribute(element, name) as? NSNumber { return number.stringValue }
    return ""
}

func frame(_ element: AXUIElement) -> CGRect {
    var origin = CGPoint.zero
    var size = CGSize.zero
    if let raw = attribute(element, kAXPositionAttribute), CFGetTypeID(raw) == AXValueGetTypeID() {
        AXValueGetValue(unsafeBitCast(raw, to: AXValue.self), .cgPoint, &origin)
    }
    if let raw = attribute(element, kAXSizeAttribute), CFGetTypeID(raw) == AXValueGetTypeID() {
        AXValueGetValue(unsafeBitCast(raw, to: AXValue.self), .cgSize, &size)
    }
    return CGRect(origin: origin, size: size)
}

func descendants(_ element: AXUIElement, depth: Int = 0) -> [AXUIElement] {
    guard depth < 14, let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement] else { return [] }
    return children + children.flatMap { descendants($0, depth: depth + 1) }
}

func summarize(_ element: AXUIElement) -> String {
    let box = frame(element)
    let role = text(element, kAXRoleAttribute)
    let title = text(element, kAXTitleAttribute)
    let description = text(element, kAXDescriptionAttribute)
    let position = "@\(Int(box.origin.x)),\(Int(box.origin.y))"
    let extent = "\(Int(box.width))x\(Int(box.height))"
    return "\(role) title=\"\(title)\" desc=\"\(description)\" \(position) \(extent)"
}

func labelled(_ application: AXUIElement, _ label: String) -> AXUIElement? {
    let pressable = [kAXButtonRole, kAXMenuBarItemRole, kAXMenuItemRole].map { $0 as String }
    return descendants(application).first {
        pressable.contains(text($0, kAXRoleAttribute))
            && (text($0, kAXTitleAttribute) == label || text($0, kAXDescriptionAttribute) == label)
    }
}

let arguments = CommandLine.arguments
guard arguments.count >= 3, let pid = pid_t(arguments[1]) else {
    print("usage: axctl <pid> list|place <x> <y>|press <label>|frame <label>|click <x> <y>|dump [depth]")
    exit(1)
}
let application = AXUIElementCreateApplication(pid)
let command = arguments[2]

switch command {
case "list":
    for element in descendants(application) {
        let role = text(element, kAXRoleAttribute)
        let interesting = [kAXButtonRole, kAXMenuBarItemRole, kAXWindowRole].map { $0 as String }
        guard interesting.contains(role) else { continue }
        print(summarize(element))
    }
case "place":
    guard arguments.count >= 5 else { exit(4) }
    let windows = (attribute(application, kAXWindowsAttribute) as? [AXUIElement]) ?? []
    let target = windows.first { !text($0, kAXTitleAttribute).isEmpty }
        ?? windows.max { frame($0).width * frame($0).height < frame($1).width * frame($1).height }
    guard let window = target else { print("no window"); exit(2) }
    var origin = CGPoint(x: Double(arguments[3]) ?? 0, y: Double(arguments[4]) ?? 0)
    AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &origin)!)
    print("placed at \(Int(origin.x)),\(Int(origin.y)) frame=\(frame(window))")
case "findbar":
    guard arguments.count >= 6,
          let from = Float(arguments[3]), let to = Float(arguments[4]), let barY = Float(arguments[5]) else { exit(4) }
    let system = AXUIElementCreateSystemWide()
    var scan = from
    while scan >= to {
        var hit: AXUIElement?
        if AXUIElementCopyElementAtPosition(system, scan, barY, &hit) == .success, let element = hit {
            var owner: pid_t = 0
            AXUIElementGetPid(element, &owner)
            if owner == pid {
                let box = frame(element)
                print("\(Int(box.origin.x)) \(Int(box.origin.y)) \(Int(box.width)) \(Int(box.height))")
                exit(0)
            }
        }
        scan -= 2
    }
    print("not found")
    exit(6)
case "press":
    guard let target = labelled(application, arguments[3]) else { print("not found"); exit(3) }
    let status = AXUIElementPerformAction(target, kAXPressAction as CFString)
    print(status == .success ? "pressed \(arguments[3])" : "press failed \(status.rawValue)")
case "value":
    guard let target = labelled(application, arguments[3]) else { print("not found"); exit(3) }
    print(text(target, kAXValueAttribute))
case "frame":
    guard let target = labelled(application, arguments[3]) else { print("not found"); exit(3) }
    let box = frame(target)
    print("\(Int(box.origin.x)),\(Int(box.origin.y)),\(Int(box.width)),\(Int(box.height))")
case "press-at":
    guard arguments.count >= 5, let pointX = Float(arguments[3]), let pointY = Float(arguments[4]) else { exit(4) }
    var hit: AXUIElement?
    guard AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), pointX, pointY, &hit) == .success,
          let target = hit else {
        print("no element at point")
        exit(5)
    }
    let status = AXUIElementPerformAction(target, kAXPressAction as CFString)
    print("\(text(target, kAXRoleAttribute)) \(text(target, kAXDescriptionAttribute)) -> \(status == .success ? "pressed" : "failed")")
case "click":
    guard arguments.count >= 5, let pointX = Double(arguments[3]), let pointY = Double(arguments[4]) else { exit(4) }
    let point = CGPoint(x: pointX, y: pointY)
    for type in [CGEventType.leftMouseDown, .leftMouseUp] {
        CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)?
            .post(tap: .cghidEventTap)
        usleep(60_000)
    }
    print("clicked \(point)")
case "dump":
    let depth = Int(arguments.count > 3 ? arguments[3] : "6") ?? 6
    func walk(_ element: AXUIElement, _ level: Int) {
        print(String(repeating: "  ", count: level) + summarize(element))
        guard level < depth, let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement] else { return }
        for child in children { walk(child, level + 1) }
    }
    walk(application, 0)
default:
    print("unknown command")
    exit(1)
}

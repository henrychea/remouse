import AppKit
import CoreText

struct ScreenRect {
    let originX, originY, width, height: CGFloat

    init?(_ text: String) {
        let parts = text.split(separator: ",").compactMap { Double($0) }
        guard parts.count == 4 else { return nil }
        originX = parts[0]
        originY = parts[1]
        width = parts[2]
        height = parts[3]
    }

    var cg: NSRect {
        NSRect(x: originX, y: Screen.flip(originY + height), width: width, height: height)
    }
}

enum Screen {
    static var height: CGFloat { NSScreen.screens.first?.frame.height ?? 1152 }
    static func flip(_ top: CGFloat) -> CGFloat { height - top }
}

final class Backdrop: NSView {
    let spacing: CGFloat = 10

    override func draw(_ dirtyRect: NSRect) {
        NSColor(srgbRed: 0.039, green: 0.039, blue: 0.039, alpha: 1).setFill()
        bounds.fill()
        NSColor(white: 1, alpha: 0.055).setFill()
        var rowY = spacing / 2
        while rowY < bounds.height {
            var columnX = spacing / 2
            while columnX < bounds.width {
                NSRect(x: columnX - 1.2, y: rowY - 1.2, width: 2.4, height: 2.4).fill()
                columnX += spacing
            }
            rowY += spacing
        }
    }
}

final class Page: NSView {
    var textView: NSTextView?

    override func draw(_ dirtyRect: NSRect) {
        NSColor(srgbRed: 0.055, green: 0.055, blue: 0.067, alpha: 1).setFill()
        bounds.fill()
        NSColor(srgbRed: 0.149, green: 0.149, blue: 0.176, alpha: 1).setStroke()
        let border = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 16, yRadius: 16)
        border.lineWidth = 1
        border.stroke()
    }
}

func dotoFont(_ size: CGFloat) -> NSFont {
    NSFont(name: "Doto-Black_Bold", size: size) ?? NSFont.monospacedSystemFont(ofSize: size, weight: .bold)
}

func registerFont() {
    let bundleFont = Bundle.main.url(forResource: "Doto", withExtension: "ttf")
    let repoFont = URL(fileURLWithPath: "reMouse/Resources/Doto.ttf")
    guard let url = bundleFont ?? (FileManager.default.fileExists(atPath: repoFont.path) ? repoFont : nil) else { return }
    _ = CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
}

let arguments = CommandLine.arguments
var backdropRect: ScreenRect?
var pageRect: ScreenRect?
var baseLevel = -1
var argIndex = 1
while argIndex < arguments.count {
    switch arguments[argIndex] {
    case "--backdrop": backdropRect = ScreenRect(arguments[argIndex + 1]); argIndex += 2
    case "--page": pageRect = ScreenRect(arguments[argIndex + 1]); argIndex += 2
    case "--level": baseLevel = Int(arguments[argIndex + 1]) ?? baseLevel; argIndex += 2
    default: argIndex += 1
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
registerFont()

var stageWindows: [NSWindow] = []

if let rect = backdropRect {
    let window = NSWindow(contentRect: rect.cg, styleMask: [.borderless], backing: .buffered, defer: false)
    window.isOpaque = true
    window.hasShadow = false
    window.level = NSWindow.Level(rawValue: baseLevel)
    window.contentView = Backdrop(frame: NSRect(origin: .zero, size: rect.cg.size))
    window.orderFront(nil)
    stageWindows.append(window)
}

if let rect = pageRect {
    let window = NSWindow(contentRect: rect.cg, styleMask: [.borderless], backing: .buffered, defer: false)
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = false
    window.level = NSWindow.Level(rawValue: backdropRect == nil ? 0 : baseLevel + 1)
    let root = Page(frame: NSRect(origin: .zero, size: rect.cg.size))

    let header = NSTextField(labelWithString: "MOUSE WHEEL")
    header.font = dotoFont(22)
    header.textColor = NSColor(srgbRed: 0.302, green: 0.659, blue: 1, alpha: 1)
    header.frame = NSRect(x: 28, y: rect.height - 58, width: 400, height: 30)
    root.addSubview(header)

    let hint = NSTextField(labelWithString: "scroll this page")
    hint.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    hint.textColor = NSColor(white: 0.45, alpha: 1)
    hint.frame = NSRect(x: 28, y: rect.height - 80, width: 400, height: 18)
    root.addSubview(hint)

    let scrollView = NSScrollView(frame: NSRect(x: 20, y: 20, width: rect.width - 40, height: rect.height - 110))
    scrollView.drawsBackground = false
    scrollView.hasVerticalScroller = false
    scrollView.hasHorizontalScroller = false

    let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: rect.width - 40, height: rect.height - 110))
    textView.isEditable = false
    textView.isSelectable = false
    textView.drawsBackground = false
    textView.textContainerInset = NSSize(width: 12, height: 12)
    textView.textContainer?.widthTracksTextView = true
    let body = NSMutableAttributedString()
    let mono = NSFont.monospacedSystemFont(ofSize: 15, weight: .medium)
    for number in 1...200 {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: mono,
            .foregroundColor: NSColor(white: number % 10 == 0 ? 0.85 : 0.62, alpha: 1),
            .backgroundColor: number % 2 == 0 ? NSColor(srgbRed: 0.098, green: 0.098, blue: 0.11, alpha: 1) : NSColor.clear,
        ]
        let bar = String(repeating: "▮", count: number % 17 + 2)
        body.append(NSAttributedString(string: String(format: "%03d  %@\n", number, bar), attributes: attributes))
    }
    textView.textStorage?.setAttributedString(body)
    scrollView.documentView = textView
    root.addSubview(scrollView)
    root.textView = textView

    window.contentView = root
    window.orderFront(nil)
    stageWindows.append(window)
}

app.run()

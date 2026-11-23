import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

private let projectRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
private let output = projectRoot.appendingPathComponent("design/dmg")
private let fontURL = projectRoot.appendingPathComponent("reMouse/Resources/Doto.ttf")

private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

private func rgba(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        colorSpace: colorSpace,
        components: [
            CGFloat((hex >> 16) & 0xFF) / 255,
            CGFloat((hex >> 8) & 0xFF) / 255,
            CGFloat(hex & 0xFF) / 255,
            alpha,
        ]
    )!
}

private let surfaceColor = rgba(0x0A0A0A)
private let primaryColor = rgba(0x4DA8FF)
private let onSurfaceColor = rgba(0xE4FFF4, 0.55)
private let gridColor = rgba(0xE4FFF4, 0.06)
private let labelPillColor = rgba(0xE6E6EA, 0.85)
private let footerColor = rgba(0xE4FFF4, 0.5)

private enum Layout {
    static let width: CGFloat = 660
    static let height: CGFloat = 400
    static let gridStep: CGFloat = 8
    static let gridRadius: CGFloat = 0.9
    static let shaftStartX: CGFloat = 260
    static let shaftEndX: CGFloat = 358
    static let shaftY: CGFloat = 190
    static let dotStep: CGFloat = 10
    static let dotRadius: CGFloat = 3.1
    static let arrowTipX: CGFloat = 392
    static let arrowTipY: CGFloat = 190
    static let arrowHeadReach: CGFloat = 34
    static let captionBaseline: CGFloat = 262
    static let footerBaseline: CGFloat = 350
    static let labelPillTop: CGFloat = 264
    static let labelPillHeight: CGFloat = 21
    static let labelPillRadius: CGFloat = 6.5
    static let labelPillPadding: CGFloat = 9
}

private func makeContext(_ pixelsWide: Int, _ pixelsHigh: Int) -> CGContext {
    CGContext(
        data: nil,
        width: pixelsWide,
        height: pixelsHigh,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
}

private func fillDot(_ context: CGContext, at point: CGPoint, radius: CGFloat) {
    context.fillEllipse(
        in: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
    )
}

private func drawGrid(_ context: CGContext) {
    context.setFillColor(gridColor)
    var gridY = Layout.gridStep / 2
    while gridY < Layout.height {
        var gridX = Layout.gridStep / 2
        while gridX < Layout.width {
            fillDot(context, at: CGPoint(x: gridX, y: gridY), radius: Layout.gridRadius)
            gridX += Layout.gridStep
        }
        gridY += Layout.gridStep
    }
}

private func arrowDots() -> [CGPoint] {
    var dots: [CGPoint] = []
    var shaftX = Layout.shaftStartX
    while shaftX <= Layout.shaftEndX {
        dots.append(CGPoint(x: shaftX, y: Layout.shaftY))
        shaftX += Layout.dotStep
    }
    let reach = Layout.arrowHeadReach
    let diagonal = hypot(Layout.arrowTipX - Layout.shaftEndX, reach)
    let steps = Int((diagonal / Layout.dotStep).rounded())
    let dx = (Layout.arrowTipX - Layout.shaftEndX) / CGFloat(steps)
    let dy = reach / CGFloat(steps)
    for step in 0...steps {
        let offset = CGFloat(step)
        dots.append(CGPoint(x: Layout.shaftEndX + dx * offset, y: Layout.arrowTipY - reach + dy * offset))
        dots.append(CGPoint(x: Layout.shaftEndX + dx * offset, y: Layout.arrowTipY + reach - dy * offset))
    }
    return dots
}

private func drawArrow(_ context: CGContext) {
    let dots = arrowDots()
    context.setShadow(offset: .zero, blur: 10, color: rgba(0x4DA8FF, 0.5))
    context.setFillColor(primaryColor)
    for dot in dots {
        fillDot(context, at: dot, radius: Layout.dotRadius)
    }
    context.setShadow(offset: .zero, blur: 2.5, color: rgba(0x4DA8FF, 0.85))
    for dot in dots {
        fillDot(context, at: dot, radius: Layout.dotRadius)
    }
    context.setShadow(offset: .zero, blur: 0, color: nil)
}

private func font(_ name: String, _ size: CGFloat) -> CTFont {
    CTFontCreateWithName(name as CFString, size, nil)
}

private func drawCentered(
    _ text: String,
    font: CTFont,
    color: CGColor,
    tracking: CGFloat,
    baseline: CGFloat,
    context: CGContext
) {
    let attributes: [CFString: Any] = [
        kCTFontAttributeName: font,
        kCTForegroundColorAttributeName: color,
        kCTKernAttributeName: tracking,
    ]
    let attributed = CFAttributedStringCreate(nil, text as CFString, attributes as CFDictionary)!
    let line = CTLineCreateWithAttributedString(attributed)
    let width = CTLineGetTypographicBounds(line, nil, nil, nil)
    context.saveGState()
    context.translateBy(x: (Layout.width - CGFloat(width)) / 2, y: baseline)
    context.scaleBy(x: 1, y: -1)
    context.textPosition = .zero
    CTLineDraw(line, context)
    context.restoreGState()
}

private func drawLabelPills(_ context: CGContext) {
    let labelFont = CTFontCreateUIFontForLanguage(.system, 12, nil)!
    let labels: [(String, [String], CGFloat)] = [
        ("reMouse", ["reMouse", "re:Mouse"], 165),
        ("Applications", ["Applications"], 495),
    ]
    context.setFillColor(labelPillColor)
    for (_, variants, centerX) in labels {
        let width = variants.map { variant in
            CTLineGetTypographicBounds(
                CTLineCreateWithAttributedString(
                    CFAttributedStringCreate(nil, variant as CFString, [kCTFontAttributeName: labelFont] as CFDictionary)!
                ),
                nil, nil, nil
            )
        }.max() ?? 0
        let pillWidth = CGFloat(width) + Layout.labelPillPadding * 2
        let rect = CGRect(
            x: centerX - pillWidth / 2,
            y: Layout.labelPillTop,
            width: pillWidth,
            height: Layout.labelPillHeight
        )
        context.addPath(
            CGPath(
                roundedRect: rect,
                cornerWidth: Layout.labelPillRadius,
                cornerHeight: Layout.labelPillRadius,
                transform: nil
            )
        )
        context.fillPath()
    }
}

private func render(scale: CGFloat) -> CGImage {
    let context = makeContext(Int(Layout.width * scale), Int(Layout.height * scale))
    context.scaleBy(x: scale, y: scale)
    context.translateBy(x: 0, y: Layout.height)
    context.scaleBy(x: 1, y: -1)
    context.setShouldAntialias(true)
    context.setAllowsAntialiasing(true)

    context.setFillColor(surfaceColor)
    context.fill(CGRect(x: 0, y: 0, width: Layout.width, height: Layout.height))
    drawGrid(context)
    drawArrow(context)
    drawLabelPills(context)

    drawCentered(
        "DRAG TO INSTALL",
        font: font("Doto-Black", 16),
        color: onSurfaceColor,
        tracking: 3.2,
        baseline: Layout.captionBaseline,
        context: context
    )
    drawCentered(
        "Not notarized: Privacy & Security > Open Anyway",
        font: font("Doto-Black", 12),
        color: footerColor,
        tracking: 0.8,
        baseline: Layout.footerBaseline,
        context: context
    )

    return context.makeImage()!
}

private func writePNG(_ image: CGImage, to url: URL, dpi: CGFloat) {
    do {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else { throw CocoaError(.fileWriteUnknown) }
        let properties: [CFString: Any] = [
            kCGImagePropertyDPIWidth: dpi,
            kCGImagePropertyDPIHeight: dpi,
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    } catch {
        fatalError("cannot write \(url.path): \(error)")
    }
}

var registrationError: Unmanaged<CFError>?
if !CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &registrationError) {
    fatalError("cannot register \(fontURL.path)")
}

writePNG(render(scale: 1), to: output.appendingPathComponent("background.png"), dpi: 72)
writePNG(render(scale: 2), to: output.appendingPathComponent("background@2x.png"), dpi: 144)
print("wrote \(output.path)/background.png and background@2x.png")

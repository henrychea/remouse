import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

private let projectRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
private let assets = projectRoot.appendingPathComponent("reMouse/Assets.xcassets")
private let snapshots = projectRoot.appendingPathComponent("design/snapshots")

private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

private let surfaceColor = rgba(0x0A0A0A)
private let bodyColor = rgba(0xE4FFF4, 0.9)
private let primaryColor = rgba(0x4DA8FF)
private let seamColor = rgba(0x4DA8FF, 0.28)
private let gridColor = rgba(0xE4FFF4, 0.07)
private let blackColor = rgba(0x000000)
private let whiteColor = rgba(0xFFFFFF)

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

private func makeContext(_ width: Int, _ height: Int) -> CGContext {
    CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
}

private func flipped(_ context: CGContext, height: CGFloat, _ body: () -> Void) {
    context.saveGState()
    context.translateBy(x: 0, y: height)
    context.scaleBy(x: 1, y: -1)
    body()
    context.restoreGState()
}

private func fillDot(_ context: CGContext, centerX: CGFloat, centerY: CGFloat, radius: CGFloat, color: CGColor) {
    context.setFillColor(color)
    context.fillEllipse(
        in: CGRect(x: centerX - radius, y: centerY - radius, width: radius * 2, height: radius * 2)
    )
}

private func roundedPath(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

private func writePNG(_ image: CGImage, _ url: URL) {
    do {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    } catch {
        fatalError("cannot write \(url.path): \(error)")
    }
}

private func resize(_ image: CGImage, to size: Int) -> CGImage {
    let context = makeContext(size, size)
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
    return context.makeImage()!
}

private struct Dot: Hashable {
    let column: Int
    let row: Int
}

private enum Matrix {
    static let step: CGFloat = 4.6
    static let originX: CGFloat = 5.2
    static let originY: CGFloat = 6.0
    static let bodyRadius: CGFloat = 1.35
    static let arrowRadius: CGFloat = 1.65
    static let seamRadius: CGFloat = 0.95

    static let body: [Dot] = ordered(
        line(1, [6, 7, 8, 9, 10])
            + line(2, [4, 5, 11, 12])
            + line(3, [3, 13])
            + (4...15).flatMap { line($0, [2, 14]) }
            + line(16, [3, 13])
            + line(17, [3, 13])
            + line(18, [4, 5, 11, 12])
            + line(19, [6, 7, 8, 9, 10])
    )

    static let arrowUp: [Dot] = ordered(
        line(4, [8])
            + line(5, [7, 8, 9])
            + line(6, [6, 8, 10])
            + line(7, [8])
            + line(8, [8])
            + line(9, [8])
            + line(10, [8])
    )

    static let seam: [Dot] = ordered(line(11, Array(3...13)))

    static func line(_ row: Int, _ columns: [Int]) -> [Dot] {
        columns.map { Dot(column: $0, row: row) }
    }

    static func ordered(_ dots: [Dot]) -> [Dot] {
        Array(Set(dots)).sorted { ($0.row, $0.column) < ($1.row, $1.column) }
    }

    static func point(_ dot: Dot) -> CGPoint {
        CGPoint(x: originX + CGFloat(dot.column) * step, y: originY + CGFloat(dot.row) * step)
    }

    static var bounds: CGRect {
        var box = CGRect.null
        for dot in body + arrowUp + seam {
            let dotPoint = point(dot)
            box = box.union(
                CGRect(
                    x: dotPoint.x - arrowRadius,
                    y: dotPoint.y - arrowRadius,
                    width: arrowRadius * 2,
                    height: arrowRadius * 2
                )
            )
        }
        return box
    }
}

private struct MiniGlyph {
    static let outline: [Dot] = [
        Dot(column: 2, row: 0), Dot(column: 3, row: 0), Dot(column: 4, row: 0),
        Dot(column: 1, row: 1), Dot(column: 5, row: 1),
        Dot(column: 0, row: 2), Dot(column: 6, row: 2),
        Dot(column: 0, row: 3), Dot(column: 6, row: 3),
        Dot(column: 0, row: 4), Dot(column: 6, row: 4),
        Dot(column: 0, row: 5), Dot(column: 6, row: 5),
        Dot(column: 0, row: 6), Dot(column: 6, row: 6),
        Dot(column: 1, row: 7), Dot(column: 5, row: 7),
        Dot(column: 2, row: 8), Dot(column: 3, row: 8), Dot(column: 4, row: 8),
    ]

    static let arrowUp: [Dot] = [
        Dot(column: 3, row: 2),
        Dot(column: 2, row: 3), Dot(column: 3, row: 3), Dot(column: 4, row: 3),
        Dot(column: 1, row: 4), Dot(column: 3, row: 4), Dot(column: 5, row: 4),
        Dot(column: 3, row: 5),
        Dot(column: 3, row: 6),
    ]

    static let arrowDown: [Dot] = [
        Dot(column: 3, row: 2),
        Dot(column: 3, row: 3),
        Dot(column: 1, row: 4), Dot(column: 3, row: 4), Dot(column: 5, row: 4),
        Dot(column: 2, row: 5), Dot(column: 3, row: 5), Dot(column: 4, row: 5),
        Dot(column: 3, row: 6),
    ]

    static let menuArrowUp: [Dot] = [
        Dot(column: 3, row: 2),
        Dot(column: 2, row: 3), Dot(column: 4, row: 3),
        Dot(column: 3, row: 4),
        Dot(column: 3, row: 5),
        Dot(column: 3, row: 6),
    ]

    static let menuArrowDown: [Dot] = [
        Dot(column: 3, row: 2),
        Dot(column: 3, row: 3),
        Dot(column: 3, row: 4),
        Dot(column: 2, row: 5), Dot(column: 4, row: 5),
        Dot(column: 3, row: 6),
    ]

    static let tinyOutline: [Dot] = [
        Dot(column: 1, row: 0), Dot(column: 2, row: 0), Dot(column: 3, row: 0),
        Dot(column: 0, row: 1), Dot(column: 4, row: 1),
        Dot(column: 0, row: 2), Dot(column: 4, row: 2),
        Dot(column: 0, row: 3), Dot(column: 4, row: 3),
        Dot(column: 1, row: 4), Dot(column: 3, row: 4),
        Dot(column: 2, row: 5),
    ]

    static let tinyArrowUp: [Dot] = [
        Dot(column: 2, row: 1),
        Dot(column: 1, row: 2), Dot(column: 2, row: 2), Dot(column: 3, row: 2),
        Dot(column: 2, row: 3),
        Dot(column: 2, row: 4),
    ]

    static let tinyColumns = 5
    static let tinyRows = 6
}

private func drawGrid(_ context: CGContext, body: CGRect) {
    context.saveGState()
    context.addPath(roundedPath(body, 185.4 / 1024 * body.width))
    context.clip()
    var gridY = body.minY + 4
    while gridY < body.maxY {
        var gridX = body.minX + 4
        while gridX < body.maxX {
            fillDot(context, centerX: gridX, centerY: gridY, radius: 0.9, color: gridColor)
            gridX += 8
        }
        gridY += 8
    }
    context.restoreGState()
}

private func drawMatrixGlyph(_ context: CGContext, center: CGPoint, height: CGFloat) {
    let scale = height / Matrix.bounds.height
    context.saveGState()
    context.translateBy(
        x: center.x - Matrix.bounds.midX * scale,
        y: center.y - Matrix.bounds.midY * scale
    )
    context.scaleBy(x: scale, y: scale)

    for item in Matrix.body {
        let dotPoint = Matrix.point(item)
        fillDot(context, centerX: dotPoint.x, centerY: dotPoint.y, radius: Matrix.bodyRadius, color: bodyColor)
    }
    for item in Matrix.seam {
        let dotPoint = Matrix.point(item)
        fillDot(context, centerX: dotPoint.x, centerY: dotPoint.y, radius: Matrix.seamRadius, color: seamColor)
    }

    context.setShadow(offset: .zero, blur: 20, color: rgba(0x4DA8FF, 0.55))
    for item in Matrix.arrowUp {
        let dotPoint = Matrix.point(item)
        fillDot(context, centerX: dotPoint.x, centerY: dotPoint.y, radius: Matrix.arrowRadius, color: primaryColor)
    }
    context.setShadow(offset: .zero, blur: 0, color: nil)

    context.restoreGState()
}

private func drawMiniGlyph(
    _ context: CGContext,
    center: CGPoint,
    step: CGFloat,
    radius: CGFloat,
    outline: [Dot],
    arrow: [Dot],
    columns: Int = 7,
    rows: Int = 9,
    glow: CGFloat,
    outlineColor: CGColor = bodyColor,
    arrowColor: CGColor = primaryColor
) {
    func place(_ dots: [Dot], _ size: CGFloat, _ color: CGColor) {
        for item in dots {
            let dotX = center.x + (CGFloat(item.column) - CGFloat(columns - 1) / 2) * step
            let dotY = center.y + (CGFloat(item.row) - CGFloat(rows - 1) / 2) * step
            fillDot(context, centerX: dotX, centerY: dotY, radius: size, color: color)
        }
    }

    place(outline, radius, outlineColor)

    if glow > 0 {
        context.setShadow(offset: .zero, blur: glow, color: rgba(0x4DA8FF, 0.6))
    }
    place(arrow, radius, arrowColor)
    if glow > 0 {
        context.setShadow(offset: .zero, blur: 0, color: nil)
    }
}

private func renderAppIcon(_ size: Int) -> CGImage {
    let context = makeContext(size, size)
    let scale = CGFloat(size)
    let body = CGRect(
        x: 100.0 / 1024 * scale,
        y: 100.0 / 1024 * scale,
        width: 824.0 / 1024 * scale,
        height: 824.0 / 1024 * scale
    )
    let radius = 185.4 / 1024 * scale

    flipped(context, height: scale) {
        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: 10.0 / 1024 * scale),
            blur: 24.0 / 1024 * scale,
            color: rgba(0x000000, 0.45)
        )
        context.addPath(roundedPath(body, radius))
        context.setFillColor(surfaceColor)
        context.fillPath()
        context.restoreGState()

        if size >= 128 {
            drawGrid(context, body: body)
        }

        context.saveGState()
        context.addPath(roundedPath(body, radius))
        context.clip()
        drawMatrixGlyph(context, center: CGPoint(x: body.midX, y: body.midY), height: 560.0 / 1024 * scale)
        context.restoreGState()
    }

    return context.makeImage()!
}

private func renderSmallIcon(_ size: Int) -> CGImage {
    let context = makeContext(size, size)
    let scale = CGFloat(size)
    let body = CGRect(
        x: 100.0 / 1024 * scale,
        y: 100.0 / 1024 * scale,
        width: 824.0 / 1024 * scale,
        height: 824.0 / 1024 * scale
    )
    let radius = 185.4 / 1024 * scale

    flipped(context, height: scale) {
        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: 10.0 / 1024 * scale),
            blur: 24.0 / 1024 * scale,
            color: rgba(0x000000, 0.45)
        )
        context.addPath(roundedPath(body, radius))
        context.setFillColor(surfaceColor)
        context.fillPath()
        context.restoreGState()

        context.saveGState()
        context.addPath(roundedPath(body, radius))
        context.clip()
        if size <= 16 {
            drawMiniGlyph(
                context,
                center: CGPoint(x: body.midX + 0.5, y: body.midY + 0.5),
                step: scale * 0.125,
                radius: scale * 0.0375,
                outline: MiniGlyph.tinyOutline,
                arrow: MiniGlyph.tinyArrowUp,
                columns: MiniGlyph.tinyColumns,
                rows: MiniGlyph.tinyRows,
                glow: scale * 0.1
            )
        } else {
            drawMiniGlyph(
                context,
                center: CGPoint(x: body.midX, y: body.midY),
                step: scale * 0.0575,
                radius: scale * 0.024,
                outline: MiniGlyph.outline,
                arrow: MiniGlyph.arrowUp,
                glow: scale * 0.075
            )
        }
        context.restoreGState()
    }

    return context.makeImage()!
}

private let menuBarWidth = 14
private let menuBarHeight = 18

private func renderMenuBarIcon(size: Int, inverted: Bool, ink: CGColor) -> CGImage {
    let context = makeContext(menuBarWidth * size, menuBarHeight * size)
    let scale = CGFloat(size)
    flipped(context, height: CGFloat(menuBarHeight) * scale) {
        drawMiniGlyph(
            context,
            center: CGPoint(
                x: CGFloat(menuBarWidth) * scale / 2,
                y: CGFloat(menuBarHeight) * scale / 2
            ),
            step: scale * 1.8,
            radius: scale * 0.85,
            outline: MiniGlyph.outline,
            arrow: inverted ? MiniGlyph.menuArrowUp : MiniGlyph.menuArrowDown,
            glow: 0,
            outlineColor: ink,
            arrowColor: ink
        )
    }
    return context.makeImage()!
}

private func renderMenuBarPreview() -> CGImage {
    let band = 56
    let width = 320
    let height = band * 2
    let context = makeContext(width, height)

    flipped(context, height: CGFloat(height)) {
        context.setFillColor(rgba(0xECECEC))
        context.fill(CGRect(x: 0, y: 0, width: width, height: band))
        context.setFillColor(rgba(0x1C1C1E))
        context.fill(CGRect(x: 0, y: band, width: width, height: band))

        let lightIcon = renderMenuBarIcon(size: 2, inverted: true, ink: blackColor)
        let darkIcon = renderMenuBarIcon(size: 2, inverted: true, ink: whiteColor)
        let iconY = CGFloat((band - lightIcon.height) / 2)
        context.draw(
            lightIcon,
            in: CGRect(
                x: CGFloat(width) / 2 - CGFloat(lightIcon.width) / 2,
                y: iconY,
                width: CGFloat(lightIcon.width),
                height: CGFloat(lightIcon.height)
            )
        )
        context.draw(
            darkIcon,
            in: CGRect(
                x: CGFloat(width) / 2 - CGFloat(darkIcon.width) / 2,
                y: CGFloat(band) + iconY,
                width: CGFloat(darkIcon.width),
                height: CGFloat(darkIcon.height)
            )
        )
    }
    return context.makeImage()!
}

private func writeJSON(_ text: String, _ url: URL) {
    do {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    } catch {
        fatalError("cannot write \(url.path): \(error)")
    }
}

private let catalogJSON = """
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""

private let appIconJSON = """
{
  "images" : [
    {
      "filename" : "icon_16x16.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_16x16@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_32x32.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_32x32@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_128x128.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_128x128@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_256x256.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_256x256@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_512x512.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "icon_512x512@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""

private func imageSetJSON(_ base: String) -> String {
    """
    {
      "images" : [
        {
          "filename" : "\(base).png",
          "idiom" : "mac",
          "scale" : "1x"
        },
        {
          "filename" : "\(base)@2x.png",
          "idiom" : "mac",
          "scale" : "2x"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      },
      "properties" : {
        "template-rendering-intent" : "template"
      }
    }
    """
}

writeJSON(catalogJSON, assets.appendingPathComponent("Contents.json"))
writeJSON(appIconJSON, assets.appendingPathComponent("AppIcon.appiconset/Contents.json"))

let appIconSet = assets.appendingPathComponent("AppIcon.appiconset")
let masterIcon = renderAppIcon(1024)
let halfIcon = resize(masterIcon, to: 512)
let quarterIcon = resize(masterIcon, to: 256)
let eighthIcon = resize(masterIcon, to: 128)

writePNG(masterIcon, appIconSet.appendingPathComponent("icon_512x512@2x.png"))
writePNG(halfIcon, appIconSet.appendingPathComponent("icon_512x512.png"))
writePNG(halfIcon, appIconSet.appendingPathComponent("icon_256x256@2x.png"))
writePNG(quarterIcon, appIconSet.appendingPathComponent("icon_256x256.png"))
writePNG(quarterIcon, appIconSet.appendingPathComponent("icon_128x128@2x.png"))
writePNG(eighthIcon, appIconSet.appendingPathComponent("icon_128x128.png"))
writePNG(renderSmallIcon(64), appIconSet.appendingPathComponent("icon_32x32@2x.png"))
writePNG(renderSmallIcon(32), appIconSet.appendingPathComponent("icon_32x32.png"))
writePNG(renderSmallIcon(32), appIconSet.appendingPathComponent("icon_16x16@2x.png"))
writePNG(renderSmallIcon(16), appIconSet.appendingPathComponent("icon_16x16.png"))

for inverted in [true, false] {
    let base = inverted ? "MenuBarIcon" : "MenuBarIconOff"
    let folder = assets.appendingPathComponent("\(base).imageset")
    writeJSON(imageSetJSON(base), folder.appendingPathComponent("Contents.json"))
    writePNG(
        renderMenuBarIcon(size: 1, inverted: inverted, ink: blackColor),
        folder.appendingPathComponent("\(base).png")
    )
    writePNG(
        renderMenuBarIcon(size: 2, inverted: inverted, ink: blackColor),
        folder.appendingPathComponent("\(base)@2x.png")
    )
}

writePNG(masterIcon, snapshots.appendingPathComponent("app-icon-1024.png"))
writePNG(renderSmallIcon(32), snapshots.appendingPathComponent("app-icon-32.png"))
writePNG(renderMenuBarPreview(), snapshots.appendingPathComponent("menubar-icon@2x.png"))

print("icons written to \(assets.path)")

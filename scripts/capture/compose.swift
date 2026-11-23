import AppKit
import Foundation

func loadImage(_ path: String) -> CGImage {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        print("cannot read \(path)")
        exit(1)
    }
    return image
}

func savePNG(_ context: CGContext, _ path: String) {
    guard let image = context.makeImage() else { exit(1) }
    guard let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, "public.png" as CFString, 1, nil) else {
        exit(1)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { exit(1) }
}

func canvas(width: Int, height: Int, background: CGColor) -> CGContext {
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        exit(1)
    }
    context.setFillColor(background)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context
}

let ink = CGColor(srgbRed: 0.039, green: 0.039, blue: 0.039, alpha: 1)
let dot = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.055)

func dotGrid(_ context: CGContext, width: Int, height: Int, spacing: Int, radius: CGFloat, color: CGColor) {
    context.setFillColor(color)
    var rowY = spacing / 2
    while rowY < height {
        var columnX = spacing / 2
        while columnX < width {
            let box = CGRect(x: CGFloat(columnX) - radius, y: CGFloat(rowY) - radius,
                             width: radius * 2, height: radius * 2)
            context.fillEllipse(in: box)
            columnX += spacing
        }
        rowY += spacing
    }
}


func registerFont() {
    let repoFont = URL(fileURLWithPath: "reMouse/Resources/Doto.ttf")
    guard FileManager.default.fileExists(atPath: repoFont.path) else { return }
    _ = CTFontManagerRegisterFontsForURL(repoFont as CFURL, .process, nil)
}


let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    print("usage: compose diffbox <a> <b> | content <in> <out> <cropY> | menubar <icon> <dropdown> <out>")
    exit(1)
}
registerFont()

switch arguments[1] {
case "diffbox":
    let first = loadImage(arguments[2])
    let second = loadImage(arguments[3])
    let width = min(first.width, second.width)
    let height = min(first.height, second.height)
    var firstBytes = [UInt8](repeating: 0, count: width * height * 4)
    var secondBytes = [UInt8](repeating: 0, count: width * height * 4)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    firstBytes.withUnsafeMutableBytes { buffer in
        let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                               bytesPerRow: width * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.draw(first, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    secondBytes.withUnsafeMutableBytes { buffer in
        let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                               bytesPerRow: width * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.draw(second, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    var minX = width, minY = height, maxX = -1, maxY = -1
    for row in 0..<height {
        for column in 0..<width {
            let offset = (row * width + column) * 4
            let delta = abs(Int(firstBytes[offset]) - Int(secondBytes[offset]))
                + abs(Int(firstBytes[offset + 1]) - Int(secondBytes[offset + 1]))
                + abs(Int(firstBytes[offset + 2]) - Int(secondBytes[offset + 2]))
            guard delta > 24 else { continue }
            minX = min(minX, column)
            maxX = max(maxX, column)
            minY = min(minY, row)
            maxY = max(maxY, row)
        }
    }
    guard maxX >= 0 else {
        print("0 0 0 0")
        exit(0)
    }
    print("\(minX) \(minY) \(maxX - minX + 1) \(maxY - minY + 1)")
case "content":
    let image = loadImage(arguments[2])
    let cropY = arguments.count > 4 ? (Int(arguments[4]) ?? 64) : 64
    let height = image.height - cropY
    let cropped = image.cropping(to: CGRect(x: 0, y: 0, width: image.width, height: height)) ?? image
    let context = canvas(width: cropped.width, height: cropped.height, background: ink)
    context.draw(cropped, in: CGRect(x: 0, y: 0, width: cropped.width, height: cropped.height))
    savePNG(context, arguments[3])
case "menubar":
    let icon = loadImage(arguments[2])
    let dropdown = loadImage(arguments[3])
    let targetWidth = 480
    let scale = CGFloat(targetWidth) / CGFloat(dropdown.width)
    let dropdownHeight = Int((CGFloat(dropdown.height) * scale).rounded())
    let iconScale = 4
    let iconHeight = icon.height * iconScale
    let totalHeight = iconHeight + dropdownHeight
    let context = canvas(width: targetWidth, height: totalHeight, background: ink)
    context.interpolationQuality = .high
    let iconWidth = icon.width * iconScale
    context.draw(icon, in: CGRect(x: targetWidth - iconWidth, y: totalHeight - iconHeight,
                                  width: iconWidth, height: iconHeight))
    context.draw(dropdown, in: CGRect(x: 0, y: 0, width: targetWidth, height: dropdownHeight))
    savePNG(context, arguments[4])
case "grid":
    let gridWidth = Int(arguments[2]) ?? 1280
    let gridHeight = Int(arguments[3]) ?? 640
    let context = canvas(width: gridWidth, height: gridHeight, background: ink)
    dotGrid(context, width: gridWidth, height: gridHeight, spacing: 20, radius: 1.4, color: dot)
    savePNG(context, arguments[4])
default:
    print("unknown command")
    exit(1)
}

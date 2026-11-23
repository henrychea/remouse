import AppKit

for (index, screen) in NSScreen.screens.enumerated() {
    let frame = screen.frame
    print("\(index)\t\(screen.localizedName)\t\(Int(frame.origin.x))\t\(Int(frame.origin.y))\t\(Int(frame.width))\t\(Int(frame.height))\t\(Int(screen.backingScaleFactor))")
}

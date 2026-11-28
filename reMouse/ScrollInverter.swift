struct ScrollDeltas: Equatable {
    var axis1: Int64
    var axis2: Int64
    var point1: Int64
    var point2: Int64
    var fixed1: Double
    var fixed2: Double
}

struct ScrollPixels: Equatable {
    var axis1: Double
    var axis2: Double
}

let pixelsPerNotch = 48.0
let smoothStepFraction = 0.18
let smoothStopThreshold = 1.0

func invertedDeltas(_ deltas: ScrollDeltas, isContinuous: Bool, enabled: Bool) -> ScrollDeltas {
    guard enabled, !isContinuous else { return deltas }
    return ScrollDeltas(
        axis1: 0 &- deltas.axis1,
        axis2: 0 &- deltas.axis2,
        point1: 0 &- deltas.point1,
        point2: 0 &- deltas.point2,
        fixed1: -deltas.fixed1,
        fixed2: -deltas.fixed2
    )
}

func notchPixels(_ wheel: Int64, fixed: Double, points: Int64) -> Double {
    if fixed != 0 { return fixed * pixelsPerNotch }
    if wheel != 0 { return Double(wheel) * pixelsPerNotch }
    return Double(points)
}

func pixelsForNotches(_ deltas: ScrollDeltas) -> ScrollPixels {
    ScrollPixels(
        axis1: notchPixels(deltas.axis1, fixed: deltas.fixed1, points: deltas.point1),
        axis2: notchPixels(deltas.axis2, fixed: deltas.fixed2, points: deltas.point2)
    )
}

func shiftingVerticalToHorizontal(_ pixels: ScrollPixels, shift: Bool) -> ScrollPixels {
    guard shift, pixels.axis1 != 0, pixels.axis2 == 0 else { return pixels }
    return ScrollPixels(axis1: 0, axis2: pixels.axis1)
}

func easeStep(_ remaining: Double, fraction: Double = smoothStepFraction) -> Double {
    guard abs(remaining) >= smoothStopThreshold else { return 0 }
    return remaining * fraction
}

func zoomDirection(_ deltas: ScrollDeltas) -> Int {
    let axis = deltas.axis1 != 0 ? deltas.axis1 : deltas.axis2
    if axis > 0 { return 1 }
    if axis < 0 { return -1 }
    return 0
}

func shouldSmooth(bundleID: String?, excluded: Set<String>, enabled: Bool, hasModifier: Bool = false) -> Bool {
    guard enabled, !hasModifier else { return false }
    guard let bundleID = bundleID else { return true }
    return !excluded.contains(bundleID)
}

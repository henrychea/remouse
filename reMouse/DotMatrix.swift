import SwiftUI

struct DotMatrix: View {
    struct Ripple {
        let from: Bool
        let at: Date
    }

    enum Glyph {
        case mouse
        case lock
    }

    let glyph: Glyph
    let inverted: Bool
    let height: CGFloat
    var ripple: Ripple?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Role: Hashable {
        case arrow
        case body
        case seam
        case idle
    }

    private struct Look {
        let color: NSColor
        let radius: Double
        let opacity: Double
    }

    private var rows: Int { glyph == .mouse ? 21 : 18 }
    private var viewBoxHeight: CGFloat { glyph == .mouse ? 104 : 92 }
    private var width: CGFloat { height * 84 / viewBoxHeight }

    var body: some View {
        Group {
            if let ripple, !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
                    canvas(elapsed: context.date.timeIntervalSince(ripple.at), from: ripple.from)
                }
            } else {
                canvas(elapsed: nil, from: inverted)
            }
        }
        .frame(width: width, height: height)
        .accessibilityHidden(true)
    }

    private func canvas(elapsed: Double?, from: Bool) -> some View {
        Canvas { context, size in
            draw(context: &context, size: size, elapsed: elapsed, from: from)
        }
    }

    private func draw(context: inout GraphicsContext, size: CGSize, elapsed: Double?, from: Bool) {
        let scale = size.height / viewBoxHeight
        let originY: Double = glyph == .mouse ? 6.0 : 5.5
        let current = looks(inverted: inverted)
        let previous = elapsed == nil ? current : looks(inverted: from)

        context.translateBy(x: (size.width - 84 * scale) / 2, y: 0)
        context.scaleBy(x: scale, y: scale)

        for row in 0..<rows {
            for column in 0..<17 {
                let target = role(column, row, inverted: inverted)
                let source = elapsed == nil ? target : role(column, row, inverted: from)
                let delay = target == .arrow ? arrowDelay(row) : radialDelay(column, row)
                var appear: Double = 1
                var pop: Double = 1
                if let elapsed {
                    appear = clamp((elapsed - delay) / 0.22)
                    pop = 1 + 0.35 * (1 - easeOut(clamp((elapsed - delay) / 0.32)))
                }

                let fromLook = previous[source] ?? idleLook
                let toLook = current[target] ?? idleLook
                let color = blend(fromLook.color, toLook.color, appear)
                let radius = (fromLook.radius + (toLook.radius - fromLook.radius) * appear) * pop
                let opacity = fromLook.opacity + (toLook.opacity - fromLook.opacity) * appear
                let x = 5.2 + Double(column) * 4.6
                let y = originY + Double(row) * 4.6

                if target == .arrow, appear > 0.01 {
                    context.drawLayer { layer in
                        layer.addFilter(.blur(radius: 2.2))
                        layer.opacity = 0.55 * appear
                        layer.fill(Path(ellipseIn: CGRect(x: x - 2.8, y: y - 2.8, width: 5.6, height: 5.6)), with: .color(Color(nsColor: toLook.color)))
                    }
                }

                context.opacity = opacity
                context.fill(
                    Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                    with: .color(color)
                )
                context.opacity = 1
            }
        }
    }

    private var idleLook: Look {
        Look(color: Palette.ledIdle.ink, radius: 0.8, opacity: 0.45)
    }

    private func looks(inverted: Bool) -> [Role: Look] {
        if glyph == .lock {
            return [
                .arrow: Look(color: Palette.primary.ink, radius: 1.65, opacity: 1),
                .body: Look(color: Palette.onSurface.ink, radius: 1.35, opacity: 0.9),
                .seam: Look(color: Palette.onSurface.ink, radius: 1.0, opacity: 0.5),
                .idle: idleLook,
            ]
        }
        return [
            .arrow: Look(color: inverted ? Palette.primary.ink : Palette.error.ink, radius: 1.65, opacity: 1),
            .body: Look(color: inverted ? Palette.bodyLit.ink : Palette.bodyDim.ink, radius: 1.35, opacity: inverted ? 0.9 : 0.65),
            .seam: Look(color: inverted ? Palette.primary.ink : Palette.seamDim.ink, radius: 0.95, opacity: inverted ? 0.28 : 0.35),
            .idle: idleLook,
        ]
    }

    private func role(_ column: Int, _ row: Int, inverted: Bool) -> Role {
        let key = row * 17 + column
        switch glyph {
        case .mouse:
            if (inverted ? Self.arrowUpKeys : Self.arrowDownKeys).contains(key) { return .arrow }
            if Self.mouseBodyKeys.contains(key) { return .body }
            if Self.mouseSeamKeys.contains(key) { return .seam }
            return .idle
        case .lock:
            if Self.lockKeyholeKeys.contains(key) { return .arrow }
            if Self.lockBodyKeys.contains(key) { return .body }
            return .idle
        }
    }

    private func arrowDelay(_ row: Int) -> Double {
        inverted ? Double(10 - row) * 0.024 : Double(row - 4) * 0.024
    }

    private func radialDelay(_ column: Int, _ row: Int) -> Double {
        hypot(Double(column - 8), Double(row - 7)) * 0.018
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private func easeOut(_ value: Double) -> Double {
        1 - pow(1 - value, 3)
    }

    private func blend(_ from: NSColor, _ to: NSColor, _ progress: Double) -> Color {
        guard progress < 1,
              let a = from.usingColorSpace(.sRGB),
              let b = to.usingColorSpace(.sRGB)
        else { return Color(nsColor: to) }
        let t = CGFloat(clamp(progress))
        return Color(
            .sRGB,
            red: a.redComponent + (b.redComponent - a.redComponent) * t,
            green: a.greenComponent + (b.greenComponent - a.greenComponent) * t,
            blue: a.blueComponent + (b.blueComponent - a.blueComponent) * t,
            opacity: a.alphaComponent + (b.alphaComponent - a.alphaComponent) * t
        )
    }

    private static func line(_ row: Int, _ columns: [Int]) -> [Int] {
        columns.map { row * 17 + $0 }
    }

    private static let mouseBodyKeys: Set<Int> = Set(
        line(1, [6, 7, 8, 9, 10]) +
        line(2, [4, 5, 11, 12]) +
        line(3, [3, 13]) +
        (4...15).flatMap { line($0, [2, 14]) } +
        line(16, [3, 13]) +
        line(17, [3, 13]) +
        line(18, [4, 5, 11, 12]) +
        line(19, [6, 7, 8, 9, 10])
    )

    private static let arrowUpKeys: Set<Int> = Set(
        line(4, [8]) +
        line(5, [7, 8, 9]) +
        line(6, [6, 8, 10]) +
        line(7, [8]) +
        line(8, [8]) +
        line(9, [8]) +
        line(10, [8])
    )

    private static let arrowDownKeys: Set<Int> = Set(
        line(4, [8]) +
        line(5, [8]) +
        line(6, [8]) +
        line(7, [8]) +
        line(8, [6, 8, 10]) +
        line(9, [7, 8, 9]) +
        line(10, [8])
    )

    private static let mouseSeamKeys: Set<Int> = Set(line(11, Array(3...13)))

    private static let lockBodyKeys: Set<Int> = Set(
        line(1, Array(6...10)) +
        line(2, [5, 11]) +
        (3...6).flatMap { line($0, [4, 12]) } +
        line(7, Array(3...13)) +
        (8...14).flatMap { line($0, [2, 14]) } +
        line(15, Array(3...13))
    )

    private static let lockKeyholeKeys: Set<Int> = Set(
        line(10, [8]) +
        line(11, [7, 8, 9]) +
        line(12, [8]) +
        line(13, [8])
    )
}

struct DotGlyph: View {
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 10
            context.scaleBy(x: scale, y: scale)
            for point in [(3.0, 2.0), (7.0, 2.0), (2.0, 4.5), (5.0, 4.5), (8.0, 4.5), (3.0, 7.0), (5.0, 7.0), (7.0, 7.0), (5.0, 9.0)] {
                context.fill(
                    Path(ellipseIn: CGRect(x: point.0 - 0.9, y: point.1 - 0.9, width: 1.8, height: 1.8)),
                    with: .color(Palette.primary)
                )
            }
        }
        .frame(width: 10, height: 10)
        .accessibilityHidden(true)
    }
}

struct MenuBarGlyph: View {
    private static let shell: [(Double, Double)] = [
        (5, 2), (7, 2), (9, 2),
        (3, 4), (11, 4),
        (3, 6.5), (11, 6.5),
        (3, 9), (11, 9),
        (3, 11.5), (11, 11.5),
        (5, 13.5), (7, 13.5), (9, 13.5),
    ]

    private static let wheel: [(Double, Double)] = [(7, 4), (7, 6.5)]

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 14, size.height / 16)
            context.scaleBy(x: scale, y: scale)
            for point in Self.shell {
                context.fill(
                    Path(ellipseIn: CGRect(x: point.0 - 1.1, y: point.1 - 1.1, width: 2.2, height: 2.2)),
                    with: .color(Palette.onSurface)
                )
            }
            for point in Self.wheel {
                context.fill(
                    Path(ellipseIn: CGRect(x: point.0 - 1.2, y: point.1 - 1.2, width: 2.4, height: 2.4)),
                    with: .color(Palette.primary)
                )
            }
        }
        .frame(width: 14, height: 16)
        .accessibilityHidden(true)
    }
}

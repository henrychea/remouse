import CoreGraphics
import Foundation

let arguments = CommandLine.arguments
guard arguments.count >= 6,
      let pointX = Double(arguments[1]), let pointY = Double(arguments[2]),
      let lines = Int32(arguments[3]), let count = Int(arguments[4]),
      let intervalMS = Int(arguments[5]) else {
    print("usage: wheel <x> <y> <lines-per-event> <event-count> <interval-ms>")
    exit(1)
}

let location = CGPoint(x: pointX, y: pointY)
for _ in 0..<count {
    guard let event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: lines, wheel2: 0, wheel3: 0) else { continue }
    event.location = location
    event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 0)
    event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: Int64(lines) * 10)
    event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: Int64(lines))
    event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: Double(lines) * 3)
    event.post(tap: .cghidEventTap)
    usleep(useconds_t(intervalMS) * 1000)
}

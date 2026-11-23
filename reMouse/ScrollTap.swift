import CoreGraphics

final class ScrollTap {
    static let shared = ScrollTap()

    private static var enabled = true
    private static var port: CFMachPort?
    private static let mask = CGEventMask(1) << CGEventType.scrollWheel.rawValue

    var isEnabled: Bool {
        get { Self.enabled }
        set { Self.enabled = newValue }
    }

    @discardableResult
    func install() -> Bool {
        if let port = Self.port {
            CGEvent.tapEnable(tap: port, enable: true)
            return true
        }
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: Self.mask,
            callback: Self.handle,
            userInfo: nil
        ) else { return false }

        Self.port = port
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        return true
    }

    func stop() {
        if let port = Self.port {
            CGEvent.tapEnable(tap: port, enable: false)
            CFMachPortInvalidate(port)
        }
        Self.port = nil
    }

    private static let handle: CGEventTapCallBack = { _, type, event, _ in
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let port = ScrollTap.port { CGEvent.tapEnable(tap: port, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type == .scrollWheel else { return Unmanaged.passUnretained(event) }

        let continuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
        let enabled = ScrollTap.enabled
        guard enabled, !continuous else { return Unmanaged.passUnretained(event) }

        let flipped = invertedDeltas(
            ScrollDeltas(
                axis1: event.getIntegerValueField(.scrollWheelEventDeltaAxis1),
                axis2: event.getIntegerValueField(.scrollWheelEventDeltaAxis2),
                point1: event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1),
                point2: event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2),
                fixed1: event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1),
                fixed2: event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)
            ),
            isContinuous: continuous,
            enabled: enabled
        )
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: flipped.axis1)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: flipped.axis2)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: flipped.point1)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: flipped.point2)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: flipped.fixed1)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: flipped.fixed2)
        return Unmanaged.passUnretained(event)
    }
}

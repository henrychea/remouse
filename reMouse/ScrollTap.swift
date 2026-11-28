import CoreGraphics

final class ScrollTap {
    static let shared = ScrollTap()

    private static var enabled = true
    private static var smooth = true
    private static var zoom = true
    private static var excludedBundleIDs: Set<String> = []
    private static var frontmostBundleID: String?
    private static var port: CFMachPort?
    private static let mask = CGEventMask(1) << CGEventType.scrollWheel.rawValue

    var isEnabled: Bool {
        get { Self.enabled }
        set { Self.enabled = newValue }
    }

    var isSmoothEnabled: Bool {
        get { Self.smooth }
        set { Self.smooth = newValue }
    }

    var isCommandZoomEnabled: Bool {
        get { Self.zoom }
        set { Self.zoom = newValue }
    }

    var smoothExcludedBundleIDs: Set<String> {
        get { Self.excludedBundleIDs }
        set { Self.excludedBundleIDs = newValue }
    }

    func setFrontmost(_ bundleID: String?) {
        guard Self.frontmostBundleID != bundleID else { return }
        Self.frontmostBundleID = bundleID
        SmoothScroll.shared.stop()
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
        SmoothScroll.shared.stop()
    }

    private static let handle: CGEventTapCallBack = { _, type, event, _ in
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let port = ScrollTap.port { CGEvent.tapEnable(tap: port, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type == .scrollWheel else { return Unmanaged.passUnretained(event) }
        guard event.getIntegerValueField(.eventSourceUserData) != SmoothScroll.userData else {
            return Unmanaged.passUnretained(event)
        }
        guard event.getIntegerValueField(.scrollWheelEventIsContinuous) == 0 else {
            return Unmanaged.passUnretained(event)
        }

        let original = ScrollDeltas(
            axis1: event.getIntegerValueField(.scrollWheelEventDeltaAxis1),
            axis2: event.getIntegerValueField(.scrollWheelEventDeltaAxis2),
            point1: event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1),
            point2: event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2),
            fixed1: event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1),
            fixed2: event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)
        )
        let flipped = invertedDeltas(original, isContinuous: false, enabled: ScrollTap.enabled)
        let hasModifier = !event.flags.isDisjoint(with: SmoothScroll.bypassModifiers)
        if hasModifier {
            SmoothScroll.shared.stop()
        }

        if ScrollTap.zoom, event.flags.contains(.maskCommand) {
            let direction = zoomDirection(flipped)
            if direction != 0 {
                SmoothScroll.postZoom(direction)
                return nil
            }
        }

        if shouldSmooth(
            bundleID: ScrollTap.frontmostBundleID,
            excluded: ScrollTap.excludedBundleIDs,
            enabled: ScrollTap.smooth,
            hasModifier: hasModifier
        ) {
            let pixels = shiftingVerticalToHorizontal(
                pixelsForNotches(flipped),
                shift: event.flags.contains(.maskShift)
            )
            if abs(pixels.axis1) >= 1 || abs(pixels.axis2) >= 1 {
                SmoothScroll.shared.add(pixels, flags: event.flags)
                return nil
            }
        }

        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: flipped.axis1)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: flipped.axis2)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: flipped.point1)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: flipped.point2)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: flipped.fixed1)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: flipped.fixed2)
        return Unmanaged.passUnretained(event)
    }
}

import Carbon
import CoreGraphics

final class SmoothScroll {
    static let shared = SmoothScroll()
    static let userData: Int64 = 0x524D_5343

    private let source = CGEventSource(stateID: .hidSystemState)
    private var timer: Timer?
    private var remaining = ScrollPixels(axis1: 0, axis2: 0)
    private var flags: CGEventFlags = []

    private init() {}

    func add(_ pixels: ScrollPixels, flags: CGEventFlags) {
        remaining.axis1 += pixels.axis1
        remaining.axis2 += pixels.axis2
        self.flags = flags
        guard timer == nil else { return }

        let timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        remaining = ScrollPixels(axis1: 0, axis2: 0)
    }

    private func tick() {
        let step1 = Int32(easeStep(remaining.axis1).rounded())
        let step2 = Int32(easeStep(remaining.axis2).rounded())
        guard step1 != 0 || step2 != 0 else {
            stop()
            return
        }

        remaining.axis1 -= Double(step1)
        remaining.axis2 -= Double(step2)
        post(step1, step2)
    }

    private func post(_ wheel1: Int32, _ wheel2: Int32) {
        guard let event = CGEvent(
            scrollWheelEvent2Source: source,
            units: .pixel,
            wheelCount: 2,
            wheel1: wheel1,
            wheel2: wheel2,
            wheel3: 0
        ) else { return }

        event.flags = flags
        event.setIntegerValueField(.eventSourceUserData, value: Self.userData)
        event.post(tap: .cgSessionEventTap)
    }

    static func postZoom(_ direction: Int) {
        let key = CGKeyCode(direction > 0 ? kVK_ANSI_Equal : kVK_ANSI_Minus)
        let source = CGEventSource(stateID: .hidSystemState)

        for isDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: isDown) else { continue }
            event.flags = .maskCommand
            event.setIntegerValueField(.eventSourceUserData, value: userData)
            event.post(tap: .cgSessionEventTap)
        }
    }
}

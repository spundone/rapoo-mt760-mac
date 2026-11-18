import AppKit
import CoreGraphics

/// Session event tap that remaps mouse buttons, runs the gesture button and reshapes
/// wheel scrolling. Runs on the main run loop. Needs Accessibility permission.
///
/// Trackpads and Magic Mice send continuous (phased) scroll events and are left alone;
/// only line-based wheel scrolling is changed. Button remaps apply to buttons 3–5 of
/// any mouse, which on a laptop in practice means external mice.
final class EventEngine {
    var settings = HostSettings()
    var frontmostBundleID: () -> String? = { nil }

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private struct Held {
        let action: HostAction
        var dx: Double = 0
        var dy: Double = 0
        var fired = false
    }
    private var held: [Int: Held] = [:]
    private let smoother = SmoothScroller()

    var isRunning: Bool { tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }

    static var accessibilityGranted: Bool { AXIsProcessTrusted() }

    static func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        guard Self.accessibilityGranted else { return false }
        let types: [CGEventType] = [.otherMouseDown, .otherMouseUp, .otherMouseDragged, .scrollWheel]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << CGEventMask($1.rawValue)) }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                           eventsOfInterest: mask, callback: { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let me = Unmanaged<EventEngine>.fromOpaque(refcon).takeUnretainedValue()
            return me.handle(type, event)
        }, userInfo: refcon) else { return false }
        tap = port
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        tap = nil
        runLoopSource = nil
        held.removeAll()
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if event.getIntegerValueField(.eventSourceUserData) == KeyPoster.marker {
            return Unmanaged.passUnretained(event)
        }
        switch type {
        case .otherMouseDown, .otherMouseUp, .otherMouseDragged:
            return handleButton(type, event)
        case .scrollWheel:
            return handleScroll(event)
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    // MARK: Buttons

    private func handleButton(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        let number = Int(event.getIntegerValueField(.mouseEventButtonNumber))
        let pass = Unmanaged.passUnretained(event)

        switch type {
        case .otherMouseDown:
            guard settings.buttonsEnabled, let button = HostButton(rawValue: number) else { return pass }
            let action = settings.action(for: button, app: frontmostBundleID())
            switch action {
            case .passthrough:
                return pass
            case .gesture, .disabled:
                held[number] = Held(action: action)
            case .mouse(let b):
                held[number] = Held(action: action)
                KeyPoster.post(mouse: b, down: true)
            default:
                held[number] = Held(action: action, fired: true)
                ActionRunner.fire(action)
            }
            return nil

        case .otherMouseDragged:
            guard var h = held[number] else { return pass }
            if case .gesture = h.action, !h.fired {
                h.dx += event.getDoubleValueField(.mouseEventDeltaX)
                h.dy += event.getDoubleValueField(.mouseEventDeltaY)
                let t = settings.gestureThreshold
                if max(abs(h.dx), abs(h.dy)) >= t {
                    h.fired = true
                    let g = settings.gestures
                    let a = abs(h.dx) > abs(h.dy) ? (h.dx < 0 ? g.left : g.right) : (h.dy < 0 ? g.up : g.down)
                    ActionRunner.fire(a)
                }
                held[number] = h
            }
            return pass

        case .otherMouseUp:
            guard let h = held.removeValue(forKey: number) else { return pass }
            switch h.action {
            case .gesture where !h.fired: ActionRunner.fire(settings.gestures.click)
            case .mouse(let b): KeyPoster.post(mouse: b, down: false)
            default: break
            }
            return nil

        default:
            return pass
        }
    }

    // MARK: Scrolling

    private func handleScroll(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        guard settings.scrollEnabled, event.getIntegerValueField(.scrollWheelEventIsContinuous) == 0 else { return pass }
        let sign: Double = settings.reverseScroll ? -1 : 1
        let k = sign * settings.scrollSpeed

        if settings.smoothScroll {
            let py = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
            let px = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2)
            // Line ticks report ~1 point per line; scale to a comfortable step.
            let lines1 = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
            let lines2 = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)
            let dy = (abs(py) > abs(lines1) ? py : lines1 * 10) * k * 4
            let dx = (abs(px) > abs(lines2) ? px : lines2 * 10) * k * 4
            smoother.add(dx: dx, dy: dy)
            return nil
        }

        if k != 1 {
            for (line, point, fixed) in [
                (CGEventField.scrollWheelEventDeltaAxis1, CGEventField.scrollWheelEventPointDeltaAxis1, CGEventField.scrollWheelEventFixedPtDeltaAxis1),
                (.scrollWheelEventDeltaAxis2, .scrollWheelEventPointDeltaAxis2, .scrollWheelEventFixedPtDeltaAxis2),
            ] {
                let l = event.getIntegerValueField(line)
                if l != 0 {
                    let scaled = Int64((Double(l) * k).rounded())
                    // Never round a notch away entirely; keep at least one line in the new direction.
                    let fallback: Int64 = k < 0 ? -l.signum() : l.signum()
                    event.setIntegerValueField(line, value: scaled == 0 ? fallback : scaled)
                }
                event.setDoubleValueField(point, value: event.getDoubleValueField(point) * k)
                event.setDoubleValueField(fixed, value: event.getDoubleValueField(fixed) * k)
            }
        }
        return pass
    }
}

/// Turns wheel ticks into a short eased stream of pixel scroll events.
final class SmoothScroller {
    private var remainingX = 0.0
    private var remainingY = 0.0
    private var timer: Timer?

    func add(dx: Double, dy: Double) {
        // Keep momentum when ticks arrive quickly, reset when direction flips.
        if dy.sign != remainingY.sign { remainingY = 0 }
        if dx.sign != remainingX.sign { remainingX = 0 }
        remainingY += dy
        remainingX += dx
        guard timer == nil else { return }
        let t = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in self?.step() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func step() {
        let fy = remainingY * 0.18, fx = remainingX * 0.18
        let sy = abs(fy) < 1 ? remainingY : fy.rounded()
        let sx = abs(fx) < 1 ? remainingX : fx.rounded()
        remainingY -= sy
        remainingX -= sx
        if Int32(sy) != 0 || Int32(sx) != 0,
           let e = CGEvent(scrollWheelEvent2Source: KeyPoster.source, units: .pixel, wheelCount: 2,
                           wheel1: Int32(sy), wheel2: Int32(sx), wheel3: 0) {
            e.setIntegerValueField(.eventSourceUserData, value: KeyPoster.marker)
            e.post(tap: .cghidEventTap)
        }
        if abs(remainingY) < 1 && abs(remainingX) < 1 {
            remainingX = 0; remainingY = 0
            timer?.invalidate()
            timer = nil
        }
    }
}

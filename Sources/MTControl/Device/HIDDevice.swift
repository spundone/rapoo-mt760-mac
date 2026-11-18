import Foundation
import IOKit.hid

/// One HID interface (a mouse exposes several: pointer, keyboard, vendor config).
struct HIDInterfaceInfo: Identifiable, Hashable, CustomStringConvertible {
    let id: UInt64            // IORegistry entry ID
    let vendorID: Int
    let productID: Int
    let product: String
    let transport: String
    let usagePage: Int
    let usage: Int
    let maxInputReport: Int
    let maxOutputReport: Int
    let maxFeatureReport: Int

    var isVendorDefined: Bool { usagePage >= 0xFF00 }

    var description: String {
        String(format: "%@ [%04X:%04X] %@ page 0x%04X usage 0x%02X in/out/feat %d/%d/%d",
               product, vendorID, productID, transport, usagePage, usage,
               maxInputReport, maxOutputReport, maxFeatureReport)
    }
}

enum HIDError: LocalizedError {
    case openFailed(IOReturn)
    case writeFailed(IOReturn)
    case readFailed(IOReturn)
    case timeout
    case notOpen

    var errorDescription: String? {
        switch self {
        case .openFailed(let r) where r == IOReturn(bitPattern: 0xE000_02E2):
            return "macOS blocked access. Turn on MT Control in System Settings → Privacy & Security → Input Monitoring, then reopen the app."
        case .openFailed(let r): return String(format: "Could not open the device (0x%08X).", r)
        case .writeFailed(let r): return String(format: "Write failed (0x%08X)", r)
        case .readFailed(let r): return String(format: "Read failed (0x%08X)", r)
        case .timeout: return "The mouse did not answer in time."
        case .notOpen: return "Device is not open."
        }
    }
}

/// Thin wrapper over one IOHIDDevice with an async request/response helper.
final class HIDConnection: @unchecked Sendable {
    let info: HIDInterfaceInfo
    private let device: IOHIDDevice
    private var inputBuffer: UnsafeMutablePointer<UInt8>
    private let bufferSize: Int
    private let lock = NSLock()
    private var waiter: ((Data) -> Bool)?
    private var waiterContinuation: CheckedContinuation<Data, Error>?
    var onUnsolicitedReport: ((Data) -> Void)?
    private(set) var isOpen = false

    init(device: IOHIDDevice, info: HIDInterfaceInfo) {
        self.device = device
        self.info = info
        self.bufferSize = max(info.maxInputReport, 64)
        self.inputBuffer = .allocate(capacity: bufferSize)
    }

    deinit {
        close()
        inputBuffer.deallocate()
    }

    func open() throws {
        guard !isOpen else { return }
        let r = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard r == kIOReturnSuccess else { throw HIDError.openFailed(r) }
        isOpen = true
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(device, inputBuffer, bufferSize, { ctx, _, _, _, reportID, report, length in
            guard let ctx else { return }
            let me = Unmanaged<HIDConnection>.fromOpaque(ctx).takeUnretainedValue()
            var bytes = Data(bytes: report, count: length)
            // macOS strips the report ID from the buffer only when the device uses none.
            if reportID != 0, bytes.first != UInt8(truncatingIfNeeded: reportID) {
                bytes.insert(UInt8(truncatingIfNeeded: reportID), at: 0)
            }
            me.handleInput(bytes)
        }, ctx)
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    }

    func close() {
        guard isOpen else { return }
        IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        isOpen = false
    }

    private func handleInput(_ data: Data) {
        lock.lock()
        if let match = waiter, match(data), let cont = waiterContinuation {
            waiter = nil
            waiterContinuation = nil
            lock.unlock()
            cont.resume(returning: data)
            return
        }
        lock.unlock()
        onUnsolicitedReport?(data)
    }

    /// Writes a report. `data[0]` must be the report ID (0 when the device has none).
    func write(_ data: Data, type: IOHIDReportType = kIOHIDReportTypeOutput) throws {
        guard isOpen else { throw HIDError.notOpen }
        let reportID = CFIndex(data.first ?? 0)
        let r = data.withUnsafeBytes { raw -> IOReturn in
            let p = raw.bindMemory(to: UInt8.self).baseAddress!
            return IOHIDDeviceSetReport(device, type, reportID, p, data.count)
        }
        guard r == kIOReturnSuccess else { throw HIDError.writeFailed(r) }
    }

    /// GET_REPORT(Input). Some firmwares only answer this way instead of with interrupt reports.
    func getInput(reportID: UInt8, length: Int) throws -> Data {
        guard isOpen else { throw HIDError.notOpen }
        var buf = [UInt8](repeating: 0, count: length)
        buf[0] = reportID
        var len = CFIndex(length)
        let r = IOHIDDeviceGetReport(device, kIOHIDReportTypeInput, CFIndex(reportID), &buf, &len)
        guard r == kIOReturnSuccess else { throw HIDError.readFailed(r) }
        return Data(buf.prefix(len))
    }

    func getFeature(reportID: UInt8, length: Int) throws -> Data {
        guard isOpen else { throw HIDError.notOpen }
        var buf = [UInt8](repeating: 0, count: length)
        buf[0] = reportID
        var len = CFIndex(length)
        let r = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, CFIndex(reportID), &buf, &len)
        guard r == kIOReturnSuccess else { throw HIDError.readFailed(r) }
        return Data(buf.prefix(len))
    }

    /// Sends `data` and waits for the first input report accepted by `match`.
    func request(_ data: Data, type: IOHIDReportType = kIOHIDReportTypeOutput,
                 timeout: TimeInterval = 1.0, match: @escaping (Data) -> Bool) async throws -> Data {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
            lock.lock()
            waiter = match
            waiterContinuation = cont
            lock.unlock()
            do {
                try write(data, type: type)
            } catch {
                lock.lock(); waiter = nil; waiterContinuation = nil; lock.unlock()
                cont.resume(throwing: error)
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
                guard let self else { return }
                self.lock.lock()
                if let c = self.waiterContinuation {
                    self.waiter = nil
                    self.waiterContinuation = nil
                    self.lock.unlock()
                    c.resume(throwing: HIDError.timeout)
                } else {
                    self.lock.unlock()
                }
            }
        }
    }
}

/// Watches for Rapoo HID interfaces coming and going.
final class HIDWatcher: @unchecked Sendable {
    static let rapooVendorID = 0x24AE

    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    private var devices: [UInt64: IOHIDDevice] = [:]
    var onChange: (([HIDInterfaceInfo]) -> Void)?

    init() {
        let match: [String: Any] = [kIOHIDVendorIDKey as String: Self.rapooVendorID]
        IOHIDManagerSetDeviceMatching(manager, match as CFDictionary)
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { ctx, _, _, device in
            guard let ctx else { return }
            Unmanaged<HIDWatcher>.fromOpaque(ctx).takeUnretainedValue().added(device)
        }, ctx)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { ctx, _, _, device in
            guard let ctx else { return }
            Unmanaged<HIDWatcher>.fromOpaque(ctx).takeUnretainedValue().removed(device)
        }, ctx)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    var interfaces: [HIDInterfaceInfo] {
        devices.values.map(Self.info(for:)).sorted { ($0.productID, $0.usagePage, $0.usage) < ($1.productID, $1.usagePage, $1.usage) }
    }

    func device(for info: HIDInterfaceInfo) -> IOHIDDevice? { devices[info.id] }

    private func added(_ d: IOHIDDevice) {
        devices[Self.entryID(d)] = d
        onChange?(interfaces)
    }

    private func removed(_ d: IOHIDDevice) {
        devices[Self.entryID(d)] = nil
        onChange?(interfaces)
    }

    static func entryID(_ d: IOHIDDevice) -> UInt64 {
        var id: UInt64 = 0
        IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(d), &id)
        return id
    }

    static func info(for d: IOHIDDevice) -> HIDInterfaceInfo {
        func int(_ k: String) -> Int { (IOHIDDeviceGetProperty(d, k as CFString) as? NSNumber)?.intValue ?? 0 }
        func str(_ k: String) -> String { (IOHIDDeviceGetProperty(d, k as CFString) as? String) ?? "" }
        return HIDInterfaceInfo(
            id: entryID(d),
            vendorID: int(kIOHIDVendorIDKey),
            productID: int(kIOHIDProductIDKey),
            product: str(kIOHIDProductKey),
            transport: str(kIOHIDTransportKey),
            usagePage: int(kIOHIDPrimaryUsagePageKey),
            usage: int(kIOHIDPrimaryUsageKey),
            maxInputReport: int(kIOHIDMaxInputReportSizeKey),
            maxOutputReport: int(kIOHIDMaxOutputReportSizeKey),
            maxFeatureReport: int(kIOHIDMaxFeatureReportSizeKey))
    }
}

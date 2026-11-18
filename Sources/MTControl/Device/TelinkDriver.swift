import Foundation

/// Read requests the app knows how to make (see docs/protocol.md §4.1).
enum ReadCommand: String, CaseIterable, Sendable {
    case firmware, battery, dpi, dpiStage, pollingRate
}

/// Packet encoding for the MT760 (Telink TLSR8273) through the 2.4 GHz receiver.
///
/// Request:  `BA A5 CMD payload…` padded to 32 bytes (A5 = relay to the mouse).
/// Response: `BA status data…`; status 01 = OK, 02 = busy. Offsets below are into the
/// response with the report ID removed, so `r[0]` is the status byte.
enum TelinkCodec {
    static let reportID = KnownDevice.configReportID
    static let route: UInt8 = 0xA5

    static func readMemory(_ address: UInt32, length: UInt8) -> [UInt8] {
        [reportID, route, 0xA4, length,
         UInt8(address & 0xFF), UInt8((address >> 8) & 0xFF), UInt8((address >> 16) & 0xFF), UInt8(address >> 24)]
    }

    /// Minimum reply length for a request: memory reads need status + 3 + len bytes.
    static func expectedLength(_ req: [UInt8]) -> Int {
        guard req.count >= 3 else { return 1 }
        switch req[2] {
        case 0xA4 where req.count >= 4: return 4 + Int(req[3])
        case 0xA3: return 5
        case 0xAA: return 3
        default: return 1
        }
    }

    static func writeMemory(_ address: UInt32, _ data: [UInt8]) -> [UInt8] {
        [reportID, route, 0xA5, UInt8(data.count),
         UInt8(address & 0xFF), UInt8((address >> 8) & 0xFF), UInt8((address >> 16) & 0xFF), UInt8(address >> 24)] + data
    }

    /// Live DPI stage on the receiver: byte 16 of the 0x638 table. Verified by pressing the
    /// top button between memory snapshots (03 → 01 → 00 → 06). 0x65C is the copy for the
    /// second (Bluetooth) table, not the live stage.
    static let dpiStageAddress: UInt32 = 0x648
    /// What 0x65C held before an early build wrote to it by mistake.
    static let bluetoothStageAddress: UInt32 = 0x65C
    static let bluetoothStageOriginal: [UInt8] = [0x00, 0xFF, 0xFF, 0xFF]

    /// Writes `[stage, old1, old2, old3]`, keeping the neighbouring bytes as read.
    static func setDPIStage(_ stage: Int, previous old: [UInt8]) -> [UInt8] {
        let o = old + [UInt8](repeating: 0xFF, count: max(0, 4 - old.count))
        return writeMemory(dpiStageAddress, [UInt8(stage), o[1], o[2], o[3]])
    }

    static func request(_ cmd: ReadCommand) -> [UInt8] {
        switch cmd {
        case .firmware: [reportID, route, 0xA3]
        case .battery: [reportID, route, 0xAA]
        case .dpi: readMemory(0x638, length: 24)
        case .dpiStage: readMemory(0x648, length: 8)
        case .pollingRate: readMemory(0x630, length: 8)
        }
    }

    /// Memory reads return data from r[4].
    static func memory(_ r: [UInt8]) -> ArraySlice<UInt8> { r.count > 4 ? r[4...] : [] }

    static func parseFirmware(_ r: [UInt8]) -> String? {
        guard r.count >= 5, r[0] == 1 else { return nil }
        return "\(r[4]).\(r[3]).\(r[2]).\(r[1])"
    }

    static func parseBattery(_ r: [UInt8]) -> (percent: Int, charging: Bool)? {
        guard r.count >= 3, r[0] == 1 else { return nil }
        return (min(Int(r[2]), 100), r[1] != 0)
    }

    /// Verified on an MT760L: `10 00 14 00 18 00 20 00 30 00 40 00 50 00 06 ff 02` =
    /// 800…4000 DPI, 7 stages, current stage index 2 (A HUB showed "dpiLevel: 3").
    static func parseDPI(_ r: [UInt8]) -> (levels: [Int], enabled: Int, current: Int)? {
        let d = Array(memory(r))
        guard r.first == 1, d.count >= 15 else { return nil }
        let levels = (0..<7).map { Int(UInt16(d[$0 * 2]) | UInt16(d[$0 * 2 + 1]) << 8) * 50 }
        let enabled = Int(d[14]) + 1
        guard levels.allSatisfy({ $0 > 0 && $0 <= 30000 }) || levels.prefix(enabled).allSatisfy({ $0 > 0 }),
              (1...7).contains(enabled) else { return nil }
        let current = d.count > 16 && d[16] < enabled ? Int(d[16]) : 0   // = 0x648
        return (levels, enabled, current)
    }

    static func parseDPIStage(_ r: [UInt8]) -> Int? {
        let d = Array(memory(r))
        guard r.first == 1, let s = d.first, s < 7 else { return nil }
        return Int(s)
    }

    /// From MouseForTelink::getDPISupportInfo: 7 stages, 50–4000 DPI, step 50.
    static let maxStages = 7
    static let dpiRange = 50...4000
    static let dpiStep = 50
    static let dpiTableAddress: UInt32 = 0x638
    static let pollingAddress: UInt32 = 0x630

    /// New 20-byte DPI table: values and stage count replaced, bytes 15–19 kept as read
    /// (byte 16 is the live stage, clamped to the new count).
    static func dpiTableWrite(levels: [Int], enabled: Int, current old: [UInt8]) -> [UInt8]? {
        guard old.count >= 20, levels.count == maxStages, (1...maxStages).contains(enabled) else { return nil }
        var t = [UInt8]()
        for dpi in levels {
            let clamped = min(max(dpi, dpiRange.lowerBound), dpiRange.upperBound)
            let v = UInt16(clamped / dpiStep)
            t += [UInt8(v & 0xFF), UInt8(v >> 8)]
        }
        t.append(UInt8(enabled - 1))
        t.append(old[15])
        t.append(min(old[16], UInt8(enabled - 1)))
        t += old[17..<20]
        return writeMemory(dpiTableAddress, t)
    }

    static func pollingWrite(_ rate: PollingRate, old: [UInt8]) -> [UInt8]? {
        guard old.count >= 4, let code = rateCodes.first(where: { $0.value == rate })?.key else { return nil }
        return writeMemory(pollingAddress, [code, code, old[2], old[3]])
    }

    /// Button slots: 4 bytes per key at 0x600 + 4 × key ID (keys 0–10).
    static let buttonMapAddress: UInt32 = 0x600
    static let buttonSlots = 11

    /// Describes one 4-byte button slot. Verified against A HUB on an MT760L:
    /// top button `03 00 04 00` = middle click, DIY `08 00 04 00` = DPI cycle −.
    static func describeButtonSlot(_ s: ArraySlice<UInt8>) -> String {
        let b = Array(s)
        guard b.count == 4 else { return "Unknown" }
        switch b[0] {
        case 0x03:
            let names = [(0x01, "Left click"), (0x02, "Right click"), (0x04, "Middle click"), (0x08, "Back"), (0x10, "Forward")]
            let on = names.filter { Int(b[2]) & $0.0 != 0 }.map(\.1)
            return on.isEmpty ? "Mouse button" : on.joined(separator: " + ")
        case 0x08:
            switch b[2] {
            case 0x03: return "DPI cycle +"
            case 0x04: return "DPI cycle −"
            case 0x05: return "DPI +"
            case 0x06: return "DPI −"
            default: return "DPI"
            }
        case 0x0B: return b[2] == 0x01 ? "Scroll up" : "Scroll down"
        case 0x0C: return b[2] == 0x01 ? "Scroll left" : "Scroll right"
        case 0x01: return HIDKey.name(for: b[2])
        case 0x02: return Modifiers(rawValue: b[2]).symbols + HIDKey.name(for: b[3])
        case 0x04:
            let usage = UInt16(b[2]) | UInt16(b[3]) << 8
            return MediaKey(rawValue: usage)?.title ?? String(format: "Media 0x%03X", usage)
        case 0x05: return "Macro \(Int(b[2]) + 1)"
        case 0x07: return "Disabled"
        case 0x09:
            switch b[2] { case 0x01: return "Sniper"; case 0x02: return "Fire"; default: return "Macro switch" }
        case 0x0A:
            switch b[2] { case 0x00: return "Polling rate switch"; case 0x02: return "Profile cycle"; case 0x03: return "Receiver cycle"; default: return "DIY" }
        case 0xFF: return "Not set"
        default: return String(format: "Unknown (%02X %02X %02X %02X)", b[0], b[1], b[2], b[3])
        }
    }

    static func parseButtonMap(_ data: [UInt8]) -> [Int: String] {
        var out: [Int: String] = [:]
        for k in 0..<min(buttonSlots, data.count / 4) {
            out[k] = describeButtonSlot(data[(k * 4)..<(k * 4 + 4)])
        }
        return out
    }

    static let rateCodes: [UInt8: PollingRate] = [0x08: .hz125, 0x04: .hz250, 0x02: .hz500, 0x01: .hz1000]

    /// data[0] = wired rate, data[1] = wireless rate.
    static func parsePollingRate(_ r: [UInt8], wireless: Bool) -> PollingRate? {
        let d = Array(memory(r))
        guard r.first == 1, d.count >= 2 else { return nil }
        return rateCodes[wireless ? d[1] : d[0]]
    }
}

/// Appends raw traffic to ~/Library/Logs/MTControl/hid.log so offsets can be checked.
enum HIDLog {
    static let url: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Logs/MTControl")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "hid.log")
    }()

    static func write(_ line: String) {
        let stamp = ISO8601DateFormatter().string(from: .now)
        let data = Data("\(stamp) \(line)\n".utf8)
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile(); h.write(data); try? h.close()
        } else {
            try? data.write(to: url)
        }
    }

    static func hex<S: Sequence>(_ bytes: S) -> String where S.Element == UInt8 {
        bytes.map { String(format: "%02x", $0) }.joined(separator: " ")
    }
}

enum DriverError: LocalizedError {
    case notSupportedYet(String)
    case busy
    case badStatus(UInt8)
    case unreadable(String)

    var errorDescription: String? {
        switch self {
        case .notSupportedYet(let what): "\(what) isn't supported yet."
        case .busy: "The mouse stayed busy. Move it to wake it up, then refresh."
        case .badStatus(let s): String(format: "The mouse answered with status 0x%02X.", s)
        case .unreadable(let what): "Couldn't make sense of the \(what) the mouse sent. Try Refresh."
        }
    }
}

/// Read-only driver for the MT760 receiver. Writes throw until they are tested.
final class TelinkDriver: MouseDriver, @unchecked Sendable {
    private let connection: HIDConnection
    private let kind: ConnectionKind

    init(connection: HIDConnection, connectionKind: ConnectionKind) {
        self.connection = connection
        self.kind = connectionKind
    }

    let capabilities: Capabilities = [.battery, .dpi, .dpiStage, .pollingRate]
    /// Writes verified on an MT760L through the receiver.
    let writable: Capabilities = [.dpiStage, .dpi, .pollingRate]

    private func ensureOpen() throws {
        guard !connection.isOpen else { return }
        if !InputMonitoring.granted { InputMonitoring.request() }
        try connection.open()
    }

    private func transact(_ cmd: ReadCommand, quiet: Bool = false) async throws -> [UInt8] {
        let req = TelinkCodec.request(cmd)
        return try await transact(req, label: cmd.rawValue, quiet: quiet, minLength: TelinkCodec.expectedLength(req))
    }

    /// Sends one packet and returns the response without the report ID (r[0] = status).
    private func transact(_ bytes: [UInt8], label: String, quiet: Bool = false, minLength: Int = 1) async throws -> [UInt8] {
        try ensureOpen()
        var packet = bytes
        packet += [UInt8](repeating: 0, count: KnownDevice.configReportLength - packet.count)
        if !quiet { HIDLog.write("→ \(label): \(HIDLog.hex(packet.prefix(max(8, bytes.count))))") }
        try await Task.sleep(for: .milliseconds(5))

        var reply: Data?
        do {
            reply = try await connection.request(Data(packet), timeout: 0.4) { $0.first == TelinkCodec.reportID }
        } catch HIDError.timeout {
            reply = nil
        }
        // Busy, or no interrupt report: poll GET_REPORT(Input) like the vendor app does.
        // Right after a change the mouse can answer with a bare status byte; treat short
        // replies like "busy" and ask again.
        func notReady(_ r: [UInt8]?) -> Bool { r == nil || r!.first == 0x02 || (r!.first == 0x01 && r!.count < minLength) }
        var r = reply.map(normalize)
        var attempts = 0
        while notReady(r) {
            attempts += 1
            guard attempts <= 100 else {
                HIDLog.write("← \(label): busy/no reply")
                throw r == nil ? HIDError.timeout : DriverError.busy
            }
            try await Task.sleep(for: .milliseconds(attempts == 1 ? 5 : 3))
            r = (try? connection.getInput(reportID: TelinkCodec.reportID, length: KnownDevice.configReportLength)).map(normalize)
            if r?.isEmpty == true { r = nil }
        }
        if !quiet { HIDLog.write("← \(label): \(HIDLog.hex(r!))") }
        guard r!.first == 1 else { throw DriverError.badStatus(r!.first ?? 0) }
        return r!
    }

    /// Strips the report ID when macOS includes it. GET_REPORT replies on this
    /// receiver arrive without it (verified: firmware reply `01 04 04 01 00`).
    private func normalize(_ d: Data) -> [UInt8] {
        let b = Array(d)
        if b.count == KnownDevice.configReportLength, b.first == TelinkCodec.reportID { return Array(b.dropFirst()) }
        return b
    }

    func readInfo() async throws -> DeviceInfo {
        var info = DeviceInfo(name: "MT760", firmware: "—", connection: kind, batteryPercent: nil, charging: false)
        if let fw = TelinkCodec.parseFirmware(try await transact(.firmware)) { info.firmware = fw }  // firmware is cosmetic
        if let b = TelinkCodec.parseBattery(try await transact(.battery)) {
            info.batteryPercent = b.percent
            info.charging = b.charging
        }
        return info
    }

    func readSettings() async throws -> MouseSettings {
        var s = MouseSettings.factory
        guard let d = TelinkCodec.parseDPI(try await transact(.dpi)) else { throw DriverError.unreadable("DPI table") }
        s.dpiLevels = d.levels
        s.enabledStages = d.enabled
        s.currentStage = d.current
        guard let p = TelinkCodec.parsePollingRate(try await transact(.pollingRate), wireless: kind != .usb) else {
            throw DriverError.unreadable("polling rate")
        }
        s.pollingRate = p
        // Button map (read-only for now). Two reads of 24 bytes; slots 0–10 use 44 of them.
        let a = TelinkCodec.readMemory(TelinkCodec.buttonMapAddress, length: 24)
        // 24-byte reads are what the snapshot uses reliably; a 20-byte read at 0x618 never completed.
        let b = TelinkCodec.readMemory(TelinkCodec.buttonMapAddress + 24, length: 24)
        if let r1 = try? await transact(a, label: "buttons 600", minLength: 28),
           let r2 = try? await transact(b, label: "buttons 618", minLength: 28) {
            s.firmwareButtons = TelinkCodec.parseButtonMap(Array(TelinkCodec.memory(r1)) + Array(TelinkCodec.memory(r2).prefix(20)))
        }
        return s
    }

    /// Read-only diagnostic: logs 0x600–0x6FF in 24-byte chunks.
    func dumpSettingsMemory(label: String) async throws {
        HIDLog.write("=== memory snapshot: \(label)")
        var addr: UInt32 = 0x600
        while addr < 0x700 {
            let len = UInt8(min(24, 0x700 - addr))
            let r = try await transact(TelinkCodec.readMemory(addr, length: len), label: String(format: "mem %03X", addr))
            _ = r
            addr += UInt32(len)
        }
        HIDLog.write("=== end snapshot")
    }

    func setDPI(levels: [Int], enabledStages: Int) async throws {
        let old = Array(TelinkCodec.memory(try await transact(.dpi)))
        guard let packet = TelinkCodec.dpiTableWrite(levels: levels, enabled: enabledStages, current: old) else {
            throw DriverError.unreadable("DPI table")
        }
        _ = try await transact(packet, label: "setDPITable")
    }
    func setCurrentStage(_ stage: Int) async throws {
        guard (0..<7).contains(stage) else { return }
        try await restoreBluetoothStageIfNeeded()
        let old = Array(TelinkCodec.memory(try await transact(.dpiStage)).prefix(4))
        _ = try await transact(TelinkCodec.setDPIStage(stage, previous: old), label: "setDPIStage(\(stage))")
    }

    /// Quiet battery read for periodic polling.
    func readBattery() async throws -> (percent: Int, charging: Bool)? {
        TelinkCodec.parseBattery(try await transact(.battery, quiet: true))
    }

    /// Cheap poll of the live stage (not logged).
    func readCurrentStage() async throws -> Int? {
        let d = Array(TelinkCodec.memory(try await transact(.dpiStage, quiet: true)))
        return d.first.map(Int.init)
    }

    /// Builds before this fix wrote stage values to 0x65C. Put back its original bytes once.
    private func restoreBluetoothStageIfNeeded() async throws {
        let key = "restoredBluetoothStage65C"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let addr = TelinkCodec.bluetoothStageAddress
        let now = Array(TelinkCodec.memory(try await transact(TelinkCodec.readMemory(addr, length: 8), label: "read 65C")).prefix(4))
        if now != TelinkCodec.bluetoothStageOriginal {
            _ = try await transact(TelinkCodec.writeMemory(addr, TelinkCodec.bluetoothStageOriginal), label: "restore 65C")
            let after = Array(TelinkCodec.memory(try await transact(TelinkCodec.readMemory(addr, length: 8), label: "verify 65C")).prefix(4))
            HIDLog.write(after == TelinkCodec.bluetoothStageOriginal ? "0x65C restored" : "0x65C still \(HIDLog.hex(after))")
        }
        UserDefaults.standard.set(true, forKey: key)
    }
    func setPollingRate(_ rate: PollingRate) async throws {
        let old = Array(TelinkCodec.memory(try await transact(.pollingRate)))
        guard let packet = TelinkCodec.pollingWrite(rate, old: old) else { throw DriverError.unreadable("polling rate") }
        _ = try await transact(packet, label: "setPollingRate(\(rate.rawValue))")
    }
    func setButton(_ id: Int, to action: ButtonAction) async throws { throw DriverError.notSupportedYet("Remapping buttons") }
    func setSleep(minutes: Int) async throws { throw DriverError.notSupportedYet("Changing sleep time") }
    func factoryReset() async throws { throw DriverError.notSupportedYet("Factory reset") }
}

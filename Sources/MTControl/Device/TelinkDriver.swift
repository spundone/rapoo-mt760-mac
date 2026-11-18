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

    static func writeMemory(_ address: UInt32, _ data: [UInt8]) -> [UInt8] {
        [reportID, route, 0xA5, UInt8(data.count),
         UInt8(address & 0xFF), UInt8((address >> 8) & 0xFF), UInt8((address >> 16) & 0xFF), UInt8(address >> 24)] + data
    }

    static let dpiStageAddress: UInt32 = 0x65C

    /// A HUB `setCurDPIGear`: write `[stage, old1, old3, old2]` (it swaps bytes 2 and 3).
    static func setDPIStage(_ stage: Int, previous old: [UInt8]) -> [UInt8] {
        let o = old + [UInt8](repeating: 0xFF, count: max(0, 4 - old.count))
        return writeMemory(dpiStageAddress, [UInt8(stage), o[1], o[3], o[2]])
    }

    static func request(_ cmd: ReadCommand) -> [UInt8] {
        switch cmd {
        case .firmware: [reportID, route, 0xA3]
        case .battery: [reportID, route, 0xAA]
        case .dpi: readMemory(0x638, length: 24)
        case .dpiStage: readMemory(0x65C, length: 8)
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
        let current = d.count > 16 && d[16] < enabled ? Int(d[16]) : 0
        return (levels, enabled, current)
    }

    static func parseDPIStage(_ r: [UInt8]) -> Int? {
        let d = Array(memory(r))
        guard r.first == 1, let s = d.first, s < 7 else { return nil }
        return Int(s)
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

    var errorDescription: String? {
        switch self {
        case .notSupportedYet(let what): "\(what) isn't supported yet."
        case .busy: "The mouse stayed busy. Move it to wake it up, then refresh."
        case .badStatus(let s): String(format: "The mouse answered with status 0x%02X.", s)
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
    /// Only stage switching is enabled so far; it is easy to undo with the mouse button.
    let writable: Capabilities = [.dpiStage]

    private func ensureOpen() throws {
        guard !connection.isOpen else { return }
        if !InputMonitoring.granted { InputMonitoring.request() }
        try connection.open()
    }

    private func transact(_ cmd: ReadCommand) async throws -> [UInt8] {
        try await transact(TelinkCodec.request(cmd), label: cmd.rawValue)
    }

    /// Sends one packet and returns the response without the report ID (r[0] = status).
    private func transact(_ bytes: [UInt8], label: String) async throws -> [UInt8] {
        try ensureOpen()
        var packet = bytes
        packet += [UInt8](repeating: 0, count: KnownDevice.configReportLength - packet.count)
        HIDLog.write("→ \(label): \(HIDLog.hex(packet.prefix(max(8, bytes.count))))")
        try await Task.sleep(for: .milliseconds(5))

        var reply: Data?
        do {
            reply = try await connection.request(Data(packet), timeout: 0.4) { $0.first == TelinkCodec.reportID }
        } catch HIDError.timeout {
            reply = nil
        }
        // Busy, or no interrupt report: poll GET_REPORT(Input) like the vendor app does.
        var r = reply.map(normalize)
        var attempts = 0
        while r == nil || r!.first == 0x02 {
            attempts += 1
            guard attempts <= 100 else {
                HIDLog.write("← \(label): busy/no reply")
                throw r == nil ? HIDError.timeout : DriverError.busy
            }
            try await Task.sleep(for: .milliseconds(attempts == 1 ? 5 : 3))
            r = (try? connection.getInput(reportID: TelinkCodec.reportID, length: KnownDevice.configReportLength)).map(normalize)
            if r?.isEmpty == true { r = nil }
        }
        HIDLog.write("← \(label): \(HIDLog.hex(r!))")
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
        if let fw = TelinkCodec.parseFirmware(try await transact(.firmware)) { info.firmware = fw }
        if let b = TelinkCodec.parseBattery(try await transact(.battery)) {
            info.batteryPercent = b.percent
            info.charging = b.charging
        }
        return info
    }

    func readSettings() async throws -> MouseSettings {
        var s = MouseSettings.factory
        if let d = TelinkCodec.parseDPI(try await transact(.dpi)) {
            s.dpiLevels = d.levels
            s.enabledStages = d.enabled
            s.currentStage = d.current
        }
        // 0x65C reads 00 while the DPI table says stage 3; logged for comparison only.
        _ = try? await transact(.dpiStage)
        if let p = TelinkCodec.parsePollingRate(try await transact(.pollingRate), wireless: kind != .usb) {
            s.pollingRate = p
        }
        return s
    }

    func setDPI(levels: [Int], enabledStages: Int) async throws { throw DriverError.notSupportedYet("Changing DPI") }
    func setCurrentStage(_ stage: Int) async throws {
        guard (0..<7).contains(stage) else { return }
        let old = Array(TelinkCodec.memory(try await transact(.dpiStage)).prefix(4))
        _ = try await transact(TelinkCodec.setDPIStage(stage, previous: old), label: "setDPIStage(\(stage))")
    }
    func setPollingRate(_ rate: PollingRate) async throws { throw DriverError.notSupportedYet("Changing polling rate") }
    func setButton(_ id: Int, to action: ButtonAction) async throws { throw DriverError.notSupportedYet("Remapping buttons") }
    func setSleep(minutes: Int) async throws { throw DriverError.notSupportedYet("Changing sleep time") }
    func factoryReset() async throws { throw DriverError.notSupportedYet("Factory reset") }
}

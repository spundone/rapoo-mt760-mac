import Testing
@testable import MTControl

@Test func readMemoryPacketLayout() {
    #expect(TelinkCodec.request(.dpi) == [0xBA, 0xA5, 0xA4, 0x18, 0x38, 0x06, 0x00, 0x00])
    #expect(TelinkCodec.request(.pollingRate) == [0xBA, 0xA5, 0xA4, 0x08, 0x30, 0x06, 0x00, 0x00])
}

@Test func parsesDPITable() {
    // status, echo(3), then 7 x u16 LE (x50 DPI), levels-1, pad, current-1
    var r: [UInt8] = [0x01, 0x18, 0x38, 0x06]
    for v in [16, 24, 32, 48, 64, 80, 100] { r += [UInt8(v & 0xFF), UInt8(v >> 8)] }
    r += [0x03, 0x00, 0x02]
    let d = TelinkCodec.parseDPI(r)
    #expect(d?.levels.prefix(4) == [800, 1200, 1600, 2400])
    #expect(d?.enabled == 4)
    #expect(d?.current == 2)
}

@Test func parsesRealMT760Replies() {
    // Captured from the user's MT760L through the receiver.
    let dpi: [UInt8] = [0x01, 0, 0, 0, 0x10, 0, 0x14, 0, 0x18, 0, 0x20, 0, 0x30, 0, 0x40, 0, 0x50, 0, 0x06, 0xff, 0x02, 0, 0x03, 0x02, 0x10, 0, 0x14, 0]
    let d = TelinkCodec.parseDPI(dpi)
    #expect(d?.levels == [800, 1000, 1200, 1600, 2400, 3200, 4000])
    #expect(d?.enabled == 7)
    #expect(d?.current == 2)
    #expect(TelinkCodec.parseFirmware([0x01, 0x04, 0x04, 0x01, 0x00]) == "0.1.4.4")
    #expect(TelinkCodec.parseBattery([0x01, 0x01, 0x63])! == (99, true))
    #expect(TelinkCodec.parsePollingRate([0x01, 0, 0, 0, 0x01, 0x01, 0xff, 0xff], wireless: true) == .hz1000)
}

@Test func parsesBatteryAndRate() {
    #expect(TelinkCodec.parseBattery([0x01, 0x00, 0x55])?.percent == 85)
    #expect(TelinkCodec.parsePollingRate([0x01, 0, 0, 0, 0x01, 0x02], wireless: true) == .hz500)
}

@Test func setDPIStagePacket() {
    // 0x648 bytes as read from the MT760L: 06 00 03 02
    #expect(TelinkCodec.setDPIStage(3, previous: [0x06, 0x00, 0x03, 0x02])
            == [0xBA, 0xA5, 0xA5, 0x04, 0x48, 0x06, 0x00, 0x00, 0x03, 0x00, 0x03, 0x02])
}

@Test func expectedReplyLengths() {
    #expect(TelinkCodec.expectedLength(TelinkCodec.request(.dpi)) == 28)
    #expect(TelinkCodec.expectedLength(TelinkCodec.request(.pollingRate)) == 12)
    #expect(TelinkCodec.expectedLength(TelinkCodec.request(.battery)) == 3)
}

@Test func dpiTableWriteKeepsTrailingBytes() {
    // Data bytes of the real table: values, 06, ff, stage 03, 00 03 02
    let old: [UInt8] = [0x10, 0, 0x14, 0, 0x18, 0, 0x20, 0, 0x30, 0, 0x40, 0, 0x50, 0, 0x06, 0xff, 0x03, 0x00, 0x03, 0x02, 0x10, 0, 0x14, 0]
    let p = TelinkCodec.dpiTableWrite(levels: [400, 800, 1600, 2400, 3200, 4000, 5000], enabled: 3, current: old)!
    #expect(Array(p.prefix(8)) == [0xBA, 0xA5, 0xA5, 20, 0x38, 0x06, 0x00, 0x00])
    let t = Array(p.dropFirst(8))
    #expect(t.count == 20)
    #expect(Array(t.prefix(4)) == [8, 0, 16, 0])          // 400, 800
    #expect(t[12] == 80 && t[13] == 0)                    // 5000 clamped to 4000
    #expect(t[14] == 2)                                   // 3 stages
    #expect(t[15] == 0xff)                                // kept
    #expect(t[16] == 2)                                   // stage 4 clamped into 3 stages
    #expect(Array(t[17...]) == [0x00, 0x03, 0x02])        // kept
}

@Test func pollingWritePacket() {
    #expect(TelinkCodec.pollingWrite(.hz500, old: [0x01, 0x01, 0xff, 0xff])
            == [0xBA, 0xA5, 0xA5, 0x04, 0x30, 0x06, 0x00, 0x00, 0x02, 0x02, 0xff, 0xff])
}

@Test func decodesRealButtonMap() {
    // 0x600–0x62B as read from the MT760L (matches A HUB's Remap page).
    let raw: [UInt8] = [3,0,1,0, 3,0,4,0, 3,0,2,0, 8,0,4,0, 3,0,4,0, 3,0,0x10,0, 3,0,8,0,
                        0x0c,0,1,0, 0x0c,0,2,0, 0x0b,0,1,0, 0x0b,0,2,0]
    let m = TelinkCodec.parseButtonMap(raw)
    #expect(m[0] == "Left click")
    #expect(m[3] == "DPI cycle −")
    #expect(m[4] == "Middle click")
    #expect(m[5] == "Forward" && m[6] == "Back")
    #expect(m[7] == "Scroll left" && m[10] == "Scroll down")
}

@Test func topButtonDPICycleUpPacket() {
    #expect(TelinkCodec.setButtonSlot(key: 4, TelinkCodec.FirmwareAction.dpiCycleUp.slot)
            == [0xBA, 0xA5, 0xA5, 0x04, 0x10, 0x06, 0x00, 0x00, 0x08, 0x00, 0x03, 0x00])
    #expect(TelinkCodec.setButtonSlot(key: 0, TelinkCodec.FirmwareAction.dpiCycleUp.slot) == nil)  // left is protected
    #expect(TelinkCodec.FirmwareAction.dpiCycleUp.title == "DPI cycle +")
}

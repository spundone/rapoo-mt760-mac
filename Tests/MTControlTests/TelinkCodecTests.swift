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

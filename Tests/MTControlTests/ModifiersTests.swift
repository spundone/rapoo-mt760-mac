import Testing
@testable import MTControl

@Test func modifierUsagesRoundTrip() {
    let m: Modifiers = [.control, .command]
    #expect(m.usages == [0xE0, 0xE3])
    #expect(Modifiers(usages: m.usages) == m)
}

@Test func presetsAreMacNative() {
    let copy = MacShortcut.all.first { $0.title == "Copy" }!
    #expect(copy.modifiers == .command)
    #expect(copy.key == 0x06)
}

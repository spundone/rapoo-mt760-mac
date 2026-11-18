import Testing
@testable import MTControl

@Test func appProfileOverridesOnlyItsButtons() {
    var s = HostSettings()
    s.global.actions[.back] = .system(.spaceLeft)
    s.global.actions[.middle] = .gesture
    var p = AppProfile(bundleID: "com.apple.Safari", name: "Safari")
    p.buttons.actions[.back] = .shortcut(.command, key: HIDKey.leftBracket)
    s.apps = [p]
    #expect(s.action(for: .back, app: "com.apple.Safari") == .shortcut(.command, key: HIDKey.leftBracket))
    #expect(s.action(for: .middle, app: "com.apple.Safari") == .gesture)       // inherited
    #expect(s.action(for: .back, app: "com.other") == .system(.spaceLeft))
    #expect(s.action(for: .forward, app: nil) == .passthrough)
}

@Test func eventTapOnlyWhenNeeded() {
    var s = HostSettings()
    #expect(!s.needsEventTap)
    s.reverseScroll = true
    #expect(s.needsEventTap)
    s.reverseScroll = false
    s.global.actions[.forward] = .disabled
    #expect(s.needsEventTap)
}

@Test func hostSettingsRoundTrip() {
    var s = HostSettings()
    s.global.actions[.middle] = .gesture
    s.gestures.up = .shortcut([.control, .command], key: HIDKey.q)
    s.apps = [AppProfile(bundleID: "a.b", name: "AB", dpiStage: 2)]
    let back = HostSettings.decode(s.encoded)
    #expect(back == s)
}

@Test func keycodeReverseMap() {
    #expect(HIDKey.macKeyCode(forHID: HIDKey.c) == 8)
    #expect(HIDKey.macKeyCode(forHID: HIDKey.upArrow) == 126)
}

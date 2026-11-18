import Foundation
import IOKit.hid

/// USB IDs and channels we know how to talk to.
enum KnownDevice {
    /// MT760 2.4 GHz receiver ("Rapoo Gaming Device").
    static let mt760Dongle = (vendor: 0x24AE, product: 0x1870)
    /// The config channel lives in the receiver's keyboard interface (page 0x01, usage 0x06)
    /// as vendor report 0xBA: 31 data bytes in and out. Opening it needs Input Monitoring.
    static let configUsagePage = 0x01
    static let configUsage = 0x06
    static let configReportID: UInt8 = 0xBA
    static let configReportLength = 32
}

enum InputMonitoring {
    static var granted: Bool { IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted }
    /// Shows the system prompt the first time; afterwards the user flips it in System Settings.
    @discardableResult static func request() -> Bool { IOHIDRequestAccess(kIOHIDRequestTypeListenEvent) }
}

enum DriverFactory {
    /// Picks the config interface of a supported mouse and builds a driver for it.
    static func makeDriver(for interfaces: [HIDInterfaceInfo], watcher: HIDWatcher) -> (MouseDriver, HIDInterfaceInfo)? {
        guard let info = interfaces.first(where: {
            $0.vendorID == KnownDevice.mt760Dongle.vendor
                && $0.productID == KnownDevice.mt760Dongle.product
                && $0.usagePage == KnownDevice.configUsagePage
                && $0.usage == KnownDevice.configUsage
                && $0.maxOutputReport >= KnownDevice.configReportLength
        }), let device = watcher.device(for: info) else { return nil }
        let connection = HIDConnection(device: device, info: info)
        return (TelinkDriver(connection: connection, connectionKind: .dongle), info)
    }
}

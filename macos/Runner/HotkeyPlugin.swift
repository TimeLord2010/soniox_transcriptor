import Cocoa
import FlutterMacOS

class HotkeyPlugin: NSObject, FlutterPlugin {
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "hotkey_plugin",
            binaryMessenger: registrar.messenger
        )
        let instance = HotkeyPlugin(channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    private let channel: FlutterMethodChannel
    private var monitor: Any?

    init(channel: FlutterMethodChannel) {
        self.channel = channel
    }

    func startListening() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard event.keyCode == 61 else { return }
            if event.modifierFlags.contains(.option) {
                self?.channel.invokeMethod("onHotkeyPressed", arguments: nil)
            } else {
                self?.channel.invokeMethod("onHotkeyReleased", arguments: nil)
            }
        }
    }

    func stopListening() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "start":
            startListening()
            result(nil)
        case "stop":
            stopListening()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

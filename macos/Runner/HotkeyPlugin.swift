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

    func pasteText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let source = CGEventSource(stateID: .hidSystemState)
        let vKeyCode: CGKeyCode = 0x09

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cgAnnotatedSessionEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "start":
            startListening()
            result(nil)
        case "stop":
            stopListening()
            result(nil)
        case "pasteText":
            if let text = call.arguments as? String {
                pasteText(text)
            }
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

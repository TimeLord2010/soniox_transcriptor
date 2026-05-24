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

    // Overlay
    private var overlayPanel: NSPanel?
    private var statusDot: NSView?
    private var transcriptionLabel: NSTextField?
    private var dotTimer: Timer?

    init(channel: FlutterMethodChannel) {
        self.channel = channel
    }

    func startListening() {
        guard ensureAccessibilityPermissions() else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard event.keyCode == 61 else { return }
            if event.modifierFlags.contains(.option) {
                self?.channel.invokeMethod("onHotkeyPressed", arguments: nil)
            } else {
                self?.channel.invokeMethod("onHotkeyReleased", arguments: nil)
            }
        }
    }

    /// Returns true if Accessibility is already granted. If not, opens the System
    /// Settings prompt and shows an alert telling the user to restart after granting.
    @discardableResult
    func ensureAccessibilityPermissions() -> Bool {
        if AXIsProcessTrusted() { return true }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)

        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility permission required"
            alert.informativeText = "Please grant Accessibility access in System Settings → Privacy & Security → Accessibility, then restart the app."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
        return false
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

        // Small delay so the previously focused app can fully regain focus before
        // we synthesize Cmd+V. Without this, release builds (AOT, faster) may post
        // the event before the target app is ready to receive it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let source = CGEventSource(stateID: .combinedSessionState)
            let vKeyCode: CGKeyCode = 0x09

            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
            keyDown?.flags = .maskCommand
            keyDown?.post(tap: .cgSessionEventTap)

            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
            keyUp?.flags = .maskCommand
            keyUp?.post(tap: .cgSessionEventTap)
        }
    }

    // MARK: - Overlay

    func showOverlay() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if self.overlayPanel == nil {
                self.buildOverlayPanel()
            }

            self.updateTranscriptionLabel(finalText: "", nonFinalText: "Ouvindo...")
            self.overlayPanel?.orderFrontRegardless()
            self.startDotAnimation()
        }
    }

    func hideOverlay() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.dotTimer?.invalidate()
            self.dotTimer = nil
            self.overlayPanel?.orderOut(nil)
        }
    }

    func updateTranscription(finalText: String, nonFinalText: String) {
        DispatchQueue.main.async { [weak self] in
            self?.updateTranscriptionLabel(finalText: finalText, nonFinalText: nonFinalText)
        }
    }

    private func buildOverlayPanel() {
        let panelWidth: CGFloat = 420
        let panelHeight: CGFloat = 90
        let margin: CGFloat = 24

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = screen.visibleFrame
        let origin = NSPoint(
            x: screenFrame.maxX - panelWidth - margin,
            y: screenFrame.minY + margin
        )

        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: CGSize(width: panelWidth, height: panelHeight)),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true

        let container = NSView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(white: 0.1, alpha: 0.88).cgColor
        container.layer?.cornerRadius = 16
        panel.contentView = container

        // Red dot
        let dotSize: CGFloat = 10
        let dot = NSView(frame: NSRect(x: 18, y: panelHeight - 18 - dotSize, width: dotSize, height: dotSize))
        dot.wantsLayer = true
        dot.layer?.backgroundColor = NSColor.systemRed.cgColor
        dot.layer?.cornerRadius = dotSize / 2
        container.addSubview(dot)
        self.statusDot = dot

        // Label
        let labelX: CGFloat = 36
        let labelPadding: CGFloat = 8
        let label = NSTextField(frame: NSRect(x: labelX, y: labelPadding, width: panelWidth - labelX - 14, height: panelHeight - labelPadding * 2))
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.maximumNumberOfLines = 4
        label.lineBreakMode = .byTruncatingHead
        label.cell?.truncatesLastVisibleLine = true
        label.cell?.wraps = true
        container.addSubview(label)
        self.transcriptionLabel = label

        self.overlayPanel = panel
    }

    private func updateTranscriptionLabel(finalText: String, nonFinalText: String) {
        guard let label = transcriptionLabel else { return }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping

        // Trim finalText from the beginning so the label always shows the most recent content
        let maxFinalChars = 150
        let displayFinal: String
        if finalText.count > maxFinalChars {
            let startIndex = finalText.index(finalText.endIndex, offsetBy: -maxFinalChars)
            displayFinal = "\u{2026}" + finalText[startIndex...]
        } else {
            displayFinal = finalText
        }

        let attributed = NSMutableAttributedString()

        if !displayFinal.isEmpty {
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.white,
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .paragraphStyle: paragraphStyle,
            ]
            attributed.append(NSAttributedString(string: displayFinal, attributes: attrs))
        }

        if !nonFinalText.isEmpty {
            let separator = displayFinal.isEmpty ? "" : " "
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor(white: 0.7, alpha: 1.0),
                .font: NSFont.systemFont(ofSize: 12, weight: .regular),
                .obliqueness: 0.15,
                .paragraphStyle: paragraphStyle,
            ]
            attributed.append(NSAttributedString(string: separator + nonFinalText, attributes: attrs))
        }

        label.attributedStringValue = attributed
    }

    private func startDotAnimation() {
        dotTimer?.invalidate()
        var visible = true
        dotTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            visible.toggle()
            self?.statusDot?.layer?.opacity = visible ? 1.0 : 0.2
        }
    }

    // MARK: - Method handler

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
        case "showOverlay":
            showOverlay()
            result(nil)
        case "hideOverlay":
            hideOverlay()
            result(nil)
        case "updateTranscription":
            if let args = call.arguments as? [String: String] {
                let finalText = args["finalText"] ?? ""
                let nonFinalText = args["nonFinalText"] ?? ""
                updateTranscription(finalText: finalText, nonFinalText: nonFinalText)
            }
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

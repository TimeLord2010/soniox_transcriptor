import Cocoa
import CoreAudio
import FlutterMacOS

/// Avisa o Flutter quando a lista de entradas de áudio ou a entrada padrão do
/// sistema mudam (CoreAudio), no lugar de ficar consultando a lista.
class InputDevicesPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var sink: FlutterEventSink?
  private var listener: AudioObjectPropertyListenerBlock?
  private var addresses: [AudioObjectPropertyAddress] = []

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = InputDevicesPlugin()
    let channel = FlutterEventChannel(
      name: "com.vit.soniox/input_devices_changed",
      binaryMessenger: registrar.messenger)
    channel.setStreamHandler(instance)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    sink = events
    let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
      self?.sink?(nil)
    }
    listener = block
    addresses = [
      AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain),
      AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain),
    ]
    for var address in addresses {
      AudioObjectAddPropertyListenerBlock(
        AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main, block)
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    if let block = listener {
      for var address in addresses {
        AudioObjectRemovePropertyListenerBlock(
          AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main, block)
      }
    }
    listener = nil
    addresses = []
    sink = nil
    return nil
  }
}

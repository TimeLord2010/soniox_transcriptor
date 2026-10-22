import AVFoundation
import AudioToolbox
import Foundation
import FlutterMacOS

class RecorderStreamDelegate: NSObject, AudioRecordingStreamDelegate {
  var config: RecordConfig?

  private var m_audioEngine: AVAudioEngine?
  private var m_amplitude: Float = -160.0
  private let m_bus = 0
  private var m_onPause: () -> ()
  private var m_onStop: () -> ()

  private var audioEncoder: AudioEnc?
  private var outputFormat: AVAudioFormat?

  /// How many times the engine is rebuilt when the system steals the input.
  ///
  /// `AVAudioEngine` re-points the input AUHAL to the *system default* input
  /// device during `start()` in some situations (with a Bluetooth headset it
  /// even goes through a private `CADefaultDeviceAggregate`), silently
  /// discarding the device selected with `setDeviceID`. The tap stays bound to
  /// the format of the requested device, so it never fires again: zero
  /// buffers, no error. Each attempt below verifies the device really stuck
  /// and retries otherwise.
  private static let maxStartAttempts = 3

  init(onPause: @escaping () -> (), onStop: @escaping () -> ()) {
    m_onPause = onPause
    m_onStop = onStop
  }

  func start(config: RecordConfig, recordEventHandler: RecordStreamHandler) throws {
    var requestedDeviceId: AudioDeviceID? = nil
    if let deviceId = config.device?.id {
      requestedDeviceId = getAudioDeviceIDFromUID(uid: deviceId)
    }

    var lastFailure = "unknown reason"

    for _ in 1...RecorderStreamDelegate.maxStartAttempts {
      let audioEngine = AVAudioEngine()

      // set input device to the node
      if let inputDeviceId = requestedDeviceId {
        do {
          try audioEngine.inputNode.auAudioUnit.setDeviceID(inputDeviceId)
        } catch {
          lastFailure = "setting input device \(inputDeviceId): \(error)"
          continue
        }
      }

      if config.echoCancel || config.autoGain {
        do {
          try setVoiceProcessing(
            echoCancel: config.echoCancel, autoGain: config.autoGain, audioEngine: audioEngine)
        } catch {
          lastFailure = "voice processing: \(error)"
          continue
        }
      }

      let srcFormat = audioEngine.inputNode.inputFormat(forBus: 0)
      guard srcFormat.sampleRate > 0 else {
        lastFailure = "input device reported an invalid format"
        continue
      }

      guard
        let dstFormat = AVAudioFormat(
          commonFormat: .pcmFormatInt16,
          sampleRate: Double(config.sampleRate),
          channels: AVAudioChannelCount(config.numChannels),
          interleaved: false
        )
      else {
        throw RecorderError.error(
          message: "Failed to start recording",
          details:
            "Format is not supported: \(config.sampleRate)Hz - \(config.numChannels) channels.")
      }

      guard let converter = AVAudioConverter(from: srcFormat, to: dstFormat) else {
        throw RecorderError.error(
          message: "Failed to start recording",
          details: "Format conversion is not possible."
        )
      }
      converter.sampleRateConverterQuality = AVAudioQuality.high.rawValue

      // Signals the arrival of the first real audio buffer of this attempt.
      let firstCallback = DispatchSemaphore(value: 0)

      audioEngine.inputNode.installTap(
        onBus: m_bus,
        bufferSize: AVAudioFrameCount(config.streamBufferSize ?? 1024),
        format: srcFormat
      ) { (buffer, _) -> Void in
        firstCallback.signal()

        self.stream(
          buffer: buffer,
          dstFormat: dstFormat,
          converter: converter,
          recordEventHandler: recordEventHandler
        )
      }

      audioEngine.prepare()

      do {
        try audioEngine.start()
      } catch {
        tearDown(audioEngine)
        lastFailure = "engine.start(): \(error)"
        continue
      }

      // Verify the engine is really capturing from the requested device: when
      // it is not, the tap above is bound to the wrong format and never fires.
      if let inputDeviceId = requestedDeviceId {
        let currentDeviceId = currentInputDeviceID(of: audioEngine)
        if currentDeviceId != inputDeviceId {
          tearDown(audioEngine)
          lastFailure =
            "requested device \(inputDeviceId) but the engine captured from "
            + "\(currentDeviceId.map(String.init) ?? "unknown")"
          continue
        }
      }

      let runningFormat = audioEngine.inputNode.inputFormat(forBus: 0)
      if runningFormat.sampleRate != srcFormat.sampleRate
        || runningFormat.channelCount != srcFormat.channelCount
      {
        tearDown(audioEngine)
        lastFailure =
          "format changed after start (\(srcFormat.sampleRate)Hz/\(srcFormat.channelCount)ch -> "
          + "\(runningFormat.sampleRate)Hz/\(runningFormat.channelCount)ch)"
        continue
      }

      // The AUHAL may report the requested device while the tap still never
      // fires — a tap bound to a format the running device does not produce is
      // silently dead on macOS. Only real audio proves the capture works.
      if firstCallback.wait(timeout: .now() + 0.5) == .timedOut {
        tearDown(audioEngine)
        lastFailure = "no audio callback within 500 ms"
        continue
      }

      self.m_audioEngine = audioEngine
      self.outputFormat = dstFormat
      self.config = config
      return
    }

    throw RecorderError.error(
      message: "Failed to start recording",
      details:
        "The audio engine did not keep the selected input device after "
        + "\(RecorderStreamDelegate.maxStartAttempts) attempts. Last failure: \(lastFailure)"
    )
  }

  func stop(completionHandler: @escaping (String?) -> ()) {
    if let audioEngine = m_audioEngine {
      do {
        try setVoiceProcessing(echoCancel: false, autoGain: false, audioEngine: audioEngine)
      } catch {}
    }

    m_audioEngine?.inputNode.removeTap(onBus: m_bus)
    m_audioEngine?.stop()
    m_audioEngine = nil

    if let encoder = audioEncoder {
      encoder.dispose()
      audioEncoder = nil
    }
    outputFormat = nil

    completionHandler(nil)
    m_onStop()

    config = nil
  }

  func pause() {
    m_audioEngine?.pause()
    m_onPause()
  }

  func resume() throws {
    try m_audioEngine?.start()
  }

  func cancel() throws {
    stop { path in }
  }

  func getAmplitude() -> Float {
    return m_amplitude
  }

  func dispose() {
    stop { path in }
  }

  /// Device the input AUHAL is really reading from.
  private func currentInputDeviceID(of audioEngine: AVAudioEngine) -> AudioDeviceID? {
    guard let unit = audioEngine.inputNode.audioUnit else {
      return nil
    }

    var deviceId = AudioDeviceID(0)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    let status = AudioUnitGetProperty(
      unit,
      kAudioOutputUnitProperty_CurrentDevice,
      kAudioUnitScope_Global,
      0,
      &deviceId,
      &size
    )

    return status == noErr ? deviceId : nil
  }

  private func tearDown(_ audioEngine: AVAudioEngine) {
    audioEngine.inputNode.removeTap(onBus: m_bus)
    audioEngine.stop()
  }

  // Set up AGC & echo cancel
  private func setVoiceProcessing(
    echoCancel: Bool, autoGain: Bool, audioEngine: AVAudioEngine
  ) throws {
    do {
      try audioEngine.inputNode.setVoiceProcessingEnabled(echoCancel)
      audioEngine.inputNode.isVoiceProcessingAGCEnabled = autoGain
    } catch {
      throw RecorderError.error(
        message: "Failed to setup voice processing",
        details: "Echo cancel error: \(error)"
      )
    }
  }

  private func updateAmplitudeInt16(buffer: AVAudioPCMBuffer) {
    guard let channelData = buffer.int16ChannelData else {
      return
    }

    let frameCount = Int(buffer.frameLength)
    let firstChannelPointer = channelData[0]
    var maxSample: Float = -160.0

    for i in 0..<frameCount {
      let curSample = abs(Float(firstChannelPointer[i]))
      if curSample > maxSample {
        maxSample = curSample
      }
    }

    m_amplitude = 20 * (log(maxSample / 32767.0) / log(10))
  }

  private func stream(
    buffer: AVAudioPCMBuffer,
    dstFormat: AVAudioFormat,
    converter: AVAudioConverter,
    recordEventHandler: RecordStreamHandler
  ) -> Void {

    guard
      let convertedBuffer = convertBuffer(
        buffer: buffer, dstFormat: dstFormat, converter: converter)
    else {
      stop { path in }
      return
    }

    updateAmplitudeInt16(buffer: convertedBuffer)

    if config?.encoder == AudioEncoder.aacLc.rawValue {
      guard let dataList = encodeAac(buffer: convertedBuffer) else {
        stop { path in }
        return
      }

      sendBytes(dataList: dataList, recordEventHandler: recordEventHandler)
    } else if config?.encoder == AudioEncoder.pcm16bits.rawValue {
      if let data = convertInt16toUInt8(buffer: convertedBuffer) {
        sendBytes(dataList: [data], recordEventHandler: recordEventHandler)
      }
    }
  }

  private func sendBytes(dataList: [Data], recordEventHandler: RecordStreamHandler) {
    // Send bytes
    if let eventSink = recordEventHandler.eventSink {
      for data in dataList {
        DispatchQueue.main.async {
          eventSink(FlutterStandardTypedData(bytes: data))
        }
      }
    }
  }

  private func convertBuffer(
    buffer: AVAudioPCMBuffer,
    dstFormat: AVAudioFormat,
    converter: AVAudioConverter
  ) -> AVAudioPCMBuffer? {
    let inputCallback: AVAudioConverterInputBlock = { inNumPackets, outStatus in
      outStatus.pointee = .haveData
      return buffer
    }

    // Determine frame capacity
    let capacity = AVAudioFrameCount(
      Double(buffer.frameLength) * dstFormat.sampleRate / buffer.format.sampleRate)

    // Destination buffer
    guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: dstFormat, frameCapacity: capacity)
    else {
      print("Unable to create output buffer")
      return nil
    }

    // Convert input buffer (resample, num channels)
    var error: NSError? = nil
    converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputCallback)
    if error != nil {
      print("Unable to convert input buffer \(error!)")
      return nil
    }

    return convertedBuffer
  }

  private func encodeAac(buffer: AVAudioPCMBuffer) -> [Data]? {
    // Lazily initialize AAC encoder
    if audioEncoder == nil {
      audioEncoder = AacAdtsEncoder()
      do {
        try audioEncoder!.setup(config: config!, format: outputFormat!)
      } catch {
        print("Failed to setup AAC encoder: \(error)")
        return nil
      }
    }

    guard let encoder = audioEncoder else {
      return nil
    }

    return encoder.encode(buffer: buffer)
  }

  // Little endian
  private func convertInt16toUInt8(buffer: AVAudioPCMBuffer) -> Data? {
    guard let channelData = buffer.int16ChannelData else {
      return nil
    }

    let frameCount = Int(buffer.frameLength)
    let channels = Int(buffer.format.channelCount)

    var bytes = Data(capacity: frameCount * channels * 2)
    for frame in 0..<frameCount {
      for ch in 0..<channels {
        let sample = channelData[ch][frame]
        bytes.append(UInt8(sample & 0x00FF))
        bytes.append(UInt8((sample >> 8) & 0x00FF))
      }
    }

    return bytes
  }
}

# PR draft — `record_macos`: selected input device is silently replaced by the system default

Target: [`llfbandit/record`](https://github.com/llfbandit/record) → `record_macos`
Checked against `record_macos` 1.2.2 (shipped with `record` 6.2.1) and 2.1.1 — the
same `AVAudioEngine` + `setDeviceID` sequence is still there.

> **Note:** the investigation and the patch below were produced by the reporter
> working with an AI assistant (analysis, measurements and code). Everything was
> reproduced and validated on the affected machine; the reproduction steps are
> included so maintainers can verify it independently.

---

## Report (from the user)

I use this package in a small macOS dictation app (`record: ^6.2.1`, so
`record_macos` 1.2.2). The app lists the input devices and lets me choose one.

My setup:

- MacBook Air M5 (`Mac17,3`), macOS 27.0.1, external LG 4K display as the main
  screen, **lid closed** (clamshell).
- **Yeti Nano** (Blue Microphones) — USB microphone, 48 kHz / 2 channels.
- **JBL Tune 720BT** — Bluetooth headset, 16 kHz / 1 channel input.

What happens:

1. I select the **Yeti Nano** in the app. Transcription works normally.
2. I connect the **JBL** over Bluetooth. From that moment on, selecting the
   **Yeti Nano** in the app produces **nothing at all**: the app connects to the
   speech-to-text service, shows "recording", and receives **zero audio**.
   No error, no warning — the transcription simply comes out empty.
3. If I switch the app back to the **JBL**, transcription works again. Switching
   to the Yeti breaks it again, every time. Restarting the app while the JBL is
   connected does not help.

One more data point that may be related: the **MacBook Air Microphone** is still
listed as an input device while the lid is closed, and it reports a healthy
48 kHz / mono stream — but the samples are pure digital silence. So if the
capture falls back to the default device in that situation, it "works" and
produces nothing, which is exactly the symptom I was seeing. With the lid
closed, only the Yeti (or another external mic) can actually pick up sound.

---

## Technical analysis

### 1. Selecting a device works; keeping it does not

`RecorderStreamDelegate.start(config:recordEventHandler:)` does:

```swift
try audioEngine.inputNode.auAudioUnit.setDeviceID(inputDeviceId)   // Yeti = HAL device 85
let srcFormat = audioEngine.inputNode.inputFormat(forBus: 0)        // 48000 Hz, 2 ch
audioEngine.inputNode.installTap(..., format: srcFormat) { ... }
audioEngine.prepare()
try audioEngine.start()
```

All of that succeeds. The problem appears **during `audioEngine.start()`**: the
engine occasionally re-points the input AUHAL to the *system default* input
device, discarding what was set above.

Measured with a small Swift program that repeats the exact sequence
(`kAudioOutputUnitProperty_CurrentDevice` read from the input AUHAL):

```
AUHAL device after setDeviceID, before start: 85 (Yeti Nano)          inputFormat=48000.0/2
AUHAL device right after start:               147 (CADefaultDeviceAggregate-89591-0)  inputFormat=16000.0/1
RESULT buffers=0 frames=0
```

Device **147** is a private aggregate that macOS creates for the default input
when that default is a Bluetooth device (`CADefaultDeviceAggregate-…`), and
16000 Hz / 1 ch is the JBL's format.

Running the same binary several times shows it is a **race**: the device sticks
in roughly half of the runs, and when it does the capture works:

```
AUHAL device right after start: 85 (Yeti Nano)  inputFormat=48000.0/2
RESULT buffers=20 frames=96000 peak=0.0147     <- real audio
```

Final measurement of the two implementations, with the JBL as the system default
input and the Yeti requested by the app (3 runs of the original code, 4 runs of
the patched one):

```
# record_macos 1.2.2, unpatched
format AFTER start: 16000.0Hz 1ch   RESULT buffers=0    frames=0       <- broken
format AFTER start: 48000.0Hz 2ch   RESULT buffers=29   frames=139200  <- lucky
format AFTER start: 16000.0Hz 1ch   RESULT buffers=0    frames=0       <- broken

# patched
OK attempts=1 buffers=21 frames=100800 peak=0.0249
OK attempts=2 buffers=21 frames=100800 peak=0.0206  (attempt 1: device stolen by 148)
OK attempts=2 buffers=21 frames=100800 peak=0.0165  (attempt 1: device stolen by 148)
OK attempts=2 buffers=21 frames=100800 peak=0.0356  (attempt 1: device stolen by 148)
```

When the device is stolen, the tap installed with the Yeti's format
(48 kHz / 2 ch) never fires again: `0` callbacks for the whole recording, and
`AVAudioEngine` reports no error — the tap is simply silent.

In some runs `start()` throws instead:

```
Error Domain=com.apple.coreaudio.avfaudio Code=-10868
  failed call=err = AUGraphParser::InitializeActiveNodesInInputChain(...)
```

One more trap found while testing the fix: the AUHAL **can report the requested
device while the tap still never fires** (`kAudioOutputUnitProperty_CurrentDevice`
= Yeti, format 48000/2, `buffers=0`). So the device property and the format are
necessary checks, not sufficient ones — the fix below also waits for the first
real audio callback before declaring the capture started.

### 2. It is not the microphone, the UID mapping or CoreAudio

- `AVCaptureDevice.uniqueID` → HAL `AudioDeviceID` lookup (`getAudioDeviceIDFromUID`)
  is correct: Yeti → 85, JBL → 114, built-in → 80, even with the JBL connected.
- Selecting the **JBL** in the app never fails because the requested device *is*
  the system default (nothing to "steal"), which matches the reported behaviour
  (works with JBL, fails with Yeti).
- Capturing the Yeti through `AVCaptureSession` (`AVCaptureDeviceInput` +
  `AVCaptureAudioDataOutput`) with the JBL still set as the system default:
  `234` buffers in 2.5 s, 48 kHz / 2 ch, **every run**. So the device selection
  itself is perfectly reliable at the CoreAudio level.

The bug is specific to how the input device is set on an `AVAudioEngine`: the
value is applied to the AUHAL, but the engine's own start-up path can override
it with the HAL default, and nothing in the API reports that it happened.

### 3. Clamshell corner case

With the lid closed the built-in microphone is still enumerated and delivers a
valid stream of pure silence:

```
RESULT MacBook Air Microphone: buffers=20 frames=96000 peak=0.00000 (48000.0Hz 1ch)
RESULT Yeti Nano:              buffers=20 frames=96000 peak=0.01360 (48000.0Hz 2ch)
```

Any silent fallback to the "default device" therefore looks like a working
microphone that transcribes nothing.

---

## Proposed fix

Keep the current `AVAudioEngine` architecture, but **verify** that the engine is
really reading from the requested device and retry when it is not, and **fail
loudly** when the capture cannot be established:

```swift
private static let maxStartAttempts = 3

func start(config: RecordConfig, recordEventHandler: RecordStreamHandler) throws {
  let requestedDeviceId: AudioDeviceID? = config.device?.id
    .flatMap { getAudioDeviceIDFromUID(uid: $0) }

  var lastFailure = "unknown reason"

  for _ in 1...Self.maxStartAttempts {
    let engine = AVAudioEngine()

    if let id = requestedDeviceId {
      try engine.inputNode.auAudioUnit.setDeviceID(id)
    }

    let srcFormat = engine.inputNode.inputFormat(forBus: 0)
    guard srcFormat.sampleRate > 0 else { continue }

    // ... dstFormat + converter ...
    // installTap(format: srcFormat) { firstCallback.signal(); /* stream(...) */ }

    engine.prepare()
    do {
      try engine.start()
    } catch {
      tearDown(engine)
      lastFailure = "engine.start(): \(error)"
      continue
    }

    // The engine may have switched to the system default device: the tap is
    // then bound to the wrong format and never fires.
    if let id = requestedDeviceId, currentInputDeviceID(of: engine) != id {
      tearDown(engine)
      lastFailure = "requested device \(id), engine captured from \(...) "
      continue
    }

    let running = engine.inputNode.inputFormat(forBus: 0)
    if running.sampleRate != srcFormat.sampleRate
        || running.channelCount != srcFormat.channelCount {
      tearDown(engine)
      lastFailure = "format changed after start"
      continue
    }

    // Device and format are necessary checks, not sufficient ones: the tap can
    // be dead even with the right device. Only a real buffer proves it works.
    if firstCallback.wait(timeout: .now() + 0.5) == .timedOut {
      tearDown(engine)
      lastFailure = "no audio callback within 500 ms"
      continue
    }

    m_audioEngine = engine
    /* ... */
    return
  }

  throw RecorderError.error(
    message: "Failed to start recording",
    details: "The audio engine did not keep the selected input device after "
      + "\(Self.maxStartAttempts) attempts. Last failure: \(lastFailure)")
}

/// Device the input AUHAL is really reading from.
private func currentInputDeviceID(of engine: AVAudioEngine) -> AudioDeviceID? {
  guard let unit = engine.inputNode.audioUnit else { return nil }
  var deviceId = AudioDeviceID(0)
  var size = UInt32(MemoryLayout<AudioDeviceID>.size)
  let status = AudioUnitGetProperty(
    unit, kAudioOutputUnitProperty_CurrentDevice,
    kAudioUnitScope_Global, 0, &deviceId, &size)
  return status == noErr ? deviceId : nil
}

private func tearDown(_ engine: AVAudioEngine) {
  engine.inputNode.removeTap(onBus: 0)
  engine.stop()
}
```

This is what the reporting app is running now (local fork of `record_macos`
1.2.2, `dependency_overrides`), and it restored the selected microphone with the
Bluetooth headset connected.

Notes / suggestions for the maintainer:

- The check must be the **AUHAL current device** (or, additionally, the first tap
  callback). `inputNode.inputFormat(forBus:)` alone is not reliable — in failed
  runs it can still report the requested format while the tap delivers nothing,
  so it cannot be the only guard.
- Failure should be an error, not silence: a stream mode that never emits a
  buffer while the UI believes it is recording is very hard to diagnose from the
  application side.
- Longer term, `AVCaptureSession` + `AVCaptureAudioDataOutput` honours the exact
  device (and never falls back to the default) at the cost of doing the
  conversion from `CMSampleBuffer` by hand. If a rewrite is on the table, that is
  the route; otherwise the verification/retry above is a small, targeted patch.
- Not specific to `record`: `inputNode.installTap(format:)` with a format that
  no longer matches the running device is silently dead on macOS.

---

## How to reproduce (standalone, no Flutter)

Save as `repro.swift`, compile with `swiftc -O repro.swift -o repro`, connect a
USB microphone, then connect a Bluetooth headset and make it the system default
input. Run it a few times: some runs print `buffers=0`.

```swift
import AVFoundation
import AudioToolbox
import CoreAudio
import Foundation

let deviceId: AudioDeviceID = 85  // your USB mic, from kAudioHardwarePropertyDevices

func deviceName(_ id: AudioDeviceID) -> String {
  var a = AudioObjectPropertyAddress(
    mSelector: kAudioObjectPropertyName, mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain)
  var s = UInt32(MemoryLayout<CFString>.size)
  var u: Unmanaged<CFString>?
  if AudioObjectGetPropertyData(id, &a, 0, nil, &s, &u) == noErr, let u = u {
    return u.takeRetainedValue() as String
  }
  return "id \(id)"
}

let engine = AVAudioEngine()
let node = engine.inputNode
try? node.auAudioUnit.setDeviceID(deviceId)

func currentDevice() -> String {
  guard let unit = node.audioUnit else { return "?" }
  var dev = AudioDeviceID(0)
  var size = UInt32(MemoryLayout<AudioDeviceID>.size)
  let st = AudioUnitGetProperty(
    unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &dev, &size)
  return st == noErr ? "\(dev) (\(deviceName(dev)))" : "err \(st)"
}

var buffers = 0, peak: Float = 0
let src = node.inputFormat(forBus: 0)
print("before start: \(currentDevice()) format=\(src.sampleRate)/\(src.channelCount)")
node.installTap(onBus: 0, bufferSize: 1024, format: src) { b, _ in
  buffers += 1
  if let ch = b.floatChannelData {
    for i in 0..<Int(b.frameLength) { peak = max(peak, abs(ch[0][i])) }
  }
}
engine.prepare()
try engine.start()
print("after start:  \(currentDevice()) format=\(node.inputFormat(forBus: 0).sampleRate)/\(node.inputFormat(forBus: 0).channelCount)")
RunLoop.current.run(until: Date().addingTimeInterval(1.5))
print("RESULT buffers=\(buffers) peak=\(peak)")
```

Expected with the bug: `after start: 147 (CADefaultDeviceAggregate-…)` followed by
`RESULT buffers=0`.

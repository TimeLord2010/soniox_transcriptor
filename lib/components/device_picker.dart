import 'package:flutter/cupertino.dart';
import 'package:record/record.dart';
import 'package:soniox_transcriptor/modules/local_storage_module.dart';
import 'package:soniox_transcriptor/repositories/recorder_repository.dart';
import 'package:vit_dart_extensions/vit_dart_extensions.dart';

class DevicePicker extends StatefulWidget {
  const DevicePicker({super.key, required this.recorder});

  final RecorderRepository recorder;

  @override
  State<DevicePicker> createState() => _DevicePickerState();
}

class _DevicePickerState extends State<DevicePicker> {
  List<InputDevice> _devices = [];
  InputDevice? _selectedDevice;

  RecorderRepository get recorder => widget.recorder;

  @override
  void initState() {
    recorder.listInputDevices().then((_) {
      setState(() {
        _devices = recorder.devices;
        _selectedDevice = recorder.selectedDevice;
      });
      _restoreSelectedDevice();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final label = _selectedDevice?.label ?? 'Padrão';
    return Row(
      children: [
        const Text('Dispositivo'),
        const Spacer(),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _devices.isEmpty ? null : () => _showDevicePicker(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              const SizedBox(width: 4),
              const Icon(CupertinoIcons.chevron_up_chevron_down, size: 14),
            ],
          ),
        ),
      ],
    );
  }

  void _showDevicePicker(BuildContext context) {
    final initialIndex = _selectedDevice == null
        ? 0
        : _devices
              .indexWhere((d) => d.id == _selectedDevice!.id)
              .clamp(0, _devices.length - 1);
    var pickerIndex = initialIndex;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => Container(
        height: 216,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: CupertinoPicker(
          scrollController: FixedExtentScrollController(
            initialItem: initialIndex,
          ),
          itemExtent: 36,
          onSelectedItemChanged: (i) => pickerIndex = i,
          children: _devices.map((d) => Center(child: Text(d.label))).toList(),
        ),
      ),
    ).then((_) {
      final picked = _devices[pickerIndex];
      setState(() => _selectedDevice = picked);
      recorder.selectedDevice = picked;
      LocalStorageModule.setSelectedDeviceLabel(picked.label);
    });
  }

  void _restoreSelectedDevice() {
    final savedLabel = LocalStorageModule.getSelectedDeviceLabel();
    if (savedLabel == null) {
      return;
    }

    InputDevice? device = _devices.firstWhereOrNull((d) {
      return d.label == savedLabel;
    });
    setState(() => _selectedDevice = device);
    recorder.selectedDevice = device;
  }
}

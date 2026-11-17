import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:record/record.dart';
import 'package:soniox_transcriptor/components/styles/ui.dart';
import 'package:soniox_transcriptor/modules/input_device_service.dart';
import 'package:soniox_transcriptor/modules/local_storage_module.dart';
import 'package:soniox_transcriptor/providers/profile_providers.dart';
import 'package:soniox_transcriptor/repositories/recorder_repository.dart';

class DevicePicker extends ConsumerStatefulWidget {
  const DevicePicker({super.key, required this.recorder});

  final RecorderRepository recorder;

  @override
  ConsumerState<DevicePicker> createState() => _DevicePickerState();
}

class _DevicePickerState extends ConsumerState<DevicePicker> {
  RecorderRepository get recorder => widget.recorder;
  InputDeviceService get _service => recorder.deviceService;

  @override
  void initState() {
    super.initState();
    // A preferência do perfil vale já; se o microfone não estiver conectado o
    // efetivo é o padrão, e volta a valer quando ele reaparecer. A lista se
    // atualiza sozinha (plugar/tirar) enquanto a tela está aberta; o
    // ListenableBuilder do build só redesenha, então não há setState após
    // dispose se a aba for trocada no meio da enumeração.
    _service.setPreferredLabel(
      LocalStorageModule.getSelectedDeviceLabel(
        ref.read(activeProfileIdProvider),
      ),
    );
    _service.watch();
    recorder.listInputDevices();
  }

  @override
  void dispose() {
    _service.unwatch();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: _service, builder: _buildRow);
  }

  Widget _buildRow(BuildContext context, Widget? _) {
    final devices = _service.devices;
    final label = _service.selected?.label ?? 'Padrão';
    // A linha é só o rótulo e o dispositivo escolhido — sem pill, sem chevron,
    // sem ícone. O botão existe apenas para dar toque e área de alvo; o texto
    // ocupa todo o espaço que sobra (é o que evita o corte em tela estreita).
    return Row(
      children: [
        const Text('Dispositivo', style: sectionLabelStyle),
        const Gap(12),
        Expanded(
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: devices.isEmpty
                ? null
                : () => _showDevicePicker(context),
            // O CupertinoButton centraliza o filho: sem o Row alinhado ao fim o
            // valor aparece no meio da linha em vez de encostar na direita.
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showDevicePicker(BuildContext context) {
    // Cópia do momento da abertura: a lista pode mudar com o sheet aberto, e
    // o índice da roda tem que continuar apontando para o mesmo item.
    final devices = List<InputDevice>.of(_service.devices);
    if (devices.isEmpty) return;
    final profileId = ref.read(activeProfileIdProvider);
    final selectedId = _service.selected?.id;
    final initialIndex = selectedId == null
        ? 0
        : devices
              .indexWhere((d) => d.id == selectedId)
              .clamp(0, devices.length - 1);
    var pickerIndex = initialIndex;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (popupContext) => Container(
        // O sheet encosta no rodapé: o inset inferior mantém a roda acima da
        // barra de gestos do Android (no macOS o inset é zero).
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(popupContext).bottom,
        ),
        color: CupertinoColors.systemBackground.resolveFrom(popupContext),
        child: SizedBox(
          height: 216,
          child: CupertinoPicker(
            scrollController: FixedExtentScrollController(
              initialItem: initialIndex,
            ),
            itemExtent: 36,
            onSelectedItemChanged: (i) => pickerIndex = i,
            children: devices.map((d) => Center(child: Text(d.label))).toList(),
          ),
        ),
      ),
    ).then((_) {
      final picked = devices[pickerIndex];
      _service.select(picked);
      LocalStorageModule.setSelectedDeviceLabel(profileId, picked.label);
    });
  }
}

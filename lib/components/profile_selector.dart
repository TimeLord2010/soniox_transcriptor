import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:soniox_transcriptor/models/profile.dart';
import 'package:soniox_transcriptor/providers/profile_providers.dart';

import 'styles/ui.dart';

class ProfileSelector extends ConsumerWidget {
  const ProfileSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeProfileProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Perfil', style: sectionLabelStyle),
        const Gap(kLabelSpacing),
        Row(
          children: [
            MenuTrigger(
              onPressed: () =>
                  showCupertinoMenuPopup(context, const _ProfilesMenu()),
              child: Text(
                active.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            const Spacer(),
            _iconButton(CupertinoIcons.add, () => _create(context, ref)),
            const Gap(8),
            _iconButton(
              CupertinoIcons.pencil,
              () => _rename(context, ref, active),
            ),
            const Gap(8),
            _iconButton(
              CupertinoIcons.trash,
              () => _delete(context, ref, active),
              enabled: !active.isDefault,
            ),
          ],
        ),
      ],
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap, {bool enabled = true}) {
    return CupertinoButton(
      padding: const EdgeInsets.all(8),
      color: CupertinoColors.systemBackground,
      borderRadius: BorderRadius.circular(8),
      onPressed: enabled ? onTap : null,
      child: Icon(
        icon,
        size: 18,
        color: enabled ? CupertinoColors.label : CupertinoColors.tertiaryLabel,
      ),
    );
  }
}

/// Lista de perfis no popup: tocar num perfil seleciona e fecha.
class _ProfilesMenu extends ConsumerWidget {
  const _ProfilesMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);
    final active = ref.watch(activeProfileProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Text(
            'Perfil',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final profile in profiles)
                MenuOptionRow(
                  label: profile.name,
                  isSelected: profile.id == active.id,
                  onTap: () {
                    ref
                        .read(activeProfileIdProvider.notifier)
                        .select(profile.id);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Pede o nome do perfil. Devolve o nome ou null quando cancelado/vazio.
Future<String?> askProfileName(
  BuildContext context, {
  required String title,
  String initial = '',
}) async {
  final value = await showCupertinoDialog<String>(
    context: context,
    builder: (_) => _NameDialog(title: title, initial: initial),
  );
  if (value == null || value.isEmpty) return null;
  return value;
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Text(widget.title),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: CupertinoTextField(
          controller: _controller,
          autofocus: true,
          placeholder: 'Nome',
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: _submit,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

// MARK: Events

Future<void> _create(BuildContext context, WidgetRef ref) async {
  final name = await askProfileName(context, title: 'Novo perfil');
  if (name == null) return;
  final profile = await ref.read(profilesProvider.notifier).create(name);
  await ref.read(activeProfileIdProvider.notifier).select(profile.id);
}

Future<void> _rename(
  BuildContext context,
  WidgetRef ref,
  Profile profile,
) async {
  final name = await askProfileName(
    context,
    title: 'Renomear perfil',
    initial: profile.name,
  );
  if (name == null) return;
  await ref.read(profilesProvider.notifier).rename(profile.id, name);
}

Future<void> _delete(
  BuildContext context,
  WidgetRef ref,
  Profile profile,
) async {
  final confirmed = await showCupertinoDialog<bool>(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: const Text('Excluir perfil'),
      content: Text(
        'Excluir o perfil "${profile.name}" e todas as suas configurações?',
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Excluir'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  await ref.read(profilesProvider.notifier).delete(profile.id);
}

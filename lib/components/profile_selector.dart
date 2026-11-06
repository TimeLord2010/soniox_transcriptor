import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:soniox_transcriptor/models/profile.dart';
import 'package:soniox_transcriptor/providers/profile_providers.dart';

import 'styles/ui.dart';

class ProfileSelector extends ConsumerWidget {
  const ProfileSelector({super.key, this.compact = false});

  /// Modo do cabeçalho da aba Início: sem rótulo de seção e sem os botões de
  /// adicionar/renomear/excluir na linha — eles vivem no popup de perfis, que
  /// é onde a lista inteira já está. Assim a linha cabe com o status da chave.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeProfileProvider);
    if (compact) {
      return MenuTrigger(
        key: const ValueKey('home-profile-trigger'),
        onPressed: () => showCupertinoMenuPopup(
          context,
          const _ProfilesMenu(withManagement: true),
        ),
        child: Flexible(
          child: Text(
            active.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      );
    }
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

/// Lista de perfis no popup: tocar num perfil seleciona e fecha. Com
/// [withManagement] o popup também carrega criar/renomear/excluir — é onde as
/// três ações vivem no cabeçalho compacto da aba Início.
class _ProfilesMenu extends ConsumerWidget {
  const _ProfilesMenu({this.withManagement = false});

  final bool withManagement;

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
        if (withManagement) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(height: 0.5, color: CupertinoColors.separator),
          ),
          _managementRow(
            key: const ValueKey('profile-new'),
            label: 'Novo perfil',
            icon: CupertinoIcons.add,
            onTap: () => _createFromMenu(context, ref),
          ),
          _managementRow(
            key: const ValueKey('profile-rename'),
            label: 'Renomear perfil',
            icon: CupertinoIcons.pencil,
            onTap: () => _renameFromMenu(context, ref, active),
          ),
          _managementRow(
            key: const ValueKey('profile-delete'),
            label: 'Excluir perfil',
            icon: CupertinoIcons.trash,
            destructive: true,
            onTap: active.isDefault
                ? null
                : () => _deleteFromMenu(context, ref, active),
          ),
        ],
      ],
    );
  }

  Widget _managementRow({
    required Key key,
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    bool destructive = false,
  }) {
    final color = onTap == null
        ? CupertinoColors.tertiaryLabel
        : destructive
        ? CupertinoColors.systemRed
        : CupertinoColors.label;
    return CupertinoButton(
      key: key,
      padding: EdgeInsets.zero,
      pressedOpacity: 0.6,
      onPressed: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Icon(icon, size: 15, color: color),
            const Gap(10),
            Text(label, style: TextStyle(fontSize: 14, color: color)),
          ],
        ),
      ),
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
  final confirmed = await _confirmDelete(context, profile);
  if (!confirmed) return;
  await ref.read(profilesProvider.notifier).delete(profile.id);
}

Future<bool> _confirmDelete(BuildContext context, Profile profile) async {
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
  return confirmed == true;
}

// MARK: Ações do popup de perfis (cabeçalho compacto)

// O diálogo abre DEPOIS de fechar o popup, e nada aqui toca `ref` depois do
// `pop`: o popup sai da árvore no mesmo frame e `ref` de widget desmontado
// lança. Por isso os notifiers são lidos antes.

Future<void> _createFromMenu(BuildContext context, WidgetRef ref) async {
  final profiles = ref.read(profilesProvider.notifier);
  final activeId = ref.read(activeProfileIdProvider.notifier);
  final root = Navigator.of(context, rootNavigator: true);
  Navigator.pop(context);
  final name = await askProfileName(root.context, title: 'Novo perfil');
  if (name == null) return;
  final profile = await profiles.create(name);
  await activeId.select(profile.id);
}

Future<void> _renameFromMenu(
  BuildContext context,
  WidgetRef ref,
  Profile profile,
) async {
  final profiles = ref.read(profilesProvider.notifier);
  final root = Navigator.of(context, rootNavigator: true);
  Navigator.pop(context);
  final name = await askProfileName(
    root.context,
    title: 'Renomear perfil',
    initial: profile.name,
  );
  if (name == null) return;
  await profiles.rename(profile.id, name);
}

Future<void> _deleteFromMenu(
  BuildContext context,
  WidgetRef ref,
  Profile profile,
) async {
  final profiles = ref.read(profilesProvider.notifier);
  final root = Navigator.of(context, rootNavigator: true);
  Navigator.pop(context);
  final confirmed = await _confirmDelete(root.context, profile);
  if (!confirmed) return;
  await profiles.delete(profile.id);
}

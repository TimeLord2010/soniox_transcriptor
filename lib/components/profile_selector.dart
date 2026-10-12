import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:soniox_transcriptor/models/profile.dart';
import 'package:soniox_transcriptor/providers/profile_providers.dart';

class ProfileSelector extends ConsumerWidget {
  const ProfileSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);
    final active = ref.watch(activeProfileProvider);
    return Column(
      crossAxisAlignment: .start,
      children: [
        Text('Perfil'),
        Row(
          children: [
            GlassMenu(
              trigger: GlassContainer(
                useOwnLayer: true,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                shape: LiquidRoundedSuperellipse(borderRadius: 10),
                child: Text(
                  active.name,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              items: [
                for (var profile in profiles)
                  GlassMenuItem(
                    title:
                        '${profile.id == active.id ? '✔ ' : ''}${profile.name}',
                    onTap: () {
                      ref
                          .read(activeProfileIdProvider.notifier)
                          .select(profile.id);
                    },
                    titleStyle: TextStyle(color: Colors.black),
                  ),
              ],
            ),
            Spacer(),
            _button(Icons.add, () => _create(context, ref)),
            Gap(10),
            _button(Icons.edit, () => _rename(context, ref, active)),
            Gap(10),
            _button(
              Icons.delete,
              () => _delete(context, ref, active),
              enabled: !active.isDefault,
            ),
          ],
        ),
      ],
    );
  }

  Widget _button(IconData icon, VoidCallback onTap, {bool enabled = true}) {
    return GlassButton(
      onTap: onTap,
      enabled: enabled,
      useOwnLayer: true,
      icon: Icon(icon, color: enabled ? Colors.black : Colors.grey),
    );
  }

  // MARK: Events

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await _askName(context, title: 'Novo perfil');
    if (name == null) return;
    final profile = await ref.read(profilesProvider.notifier).create(name);
    await ref.read(activeProfileIdProvider.notifier).select(profile.id);
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    Profile profile,
  ) async {
    final name = await _askName(
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir perfil'),
        content: Text(
          'Excluir o perfil "${profile.name}" e todas as suas configurações?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(profilesProvider.notifier).delete(profile.id);
  }

  /// Asks for a profile name. Returns null when cancelled or left empty.
  Future<String?> _askName(
    BuildContext context, {
    required String title,
    String initial = '',
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: 'Nome'),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text('Salvar'),
          ),
        ],
      ),
    ).then((value) => (value == null || value.isEmpty) ? null : value);
  }
}

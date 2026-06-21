import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:soniox_transcriptor/models/languages.dart';
import 'package:soniox_transcriptor/providers/context_providers.dart';

class LanguagePicker extends ConsumerWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Set<Language> langs = ref.watch(languagesProvider);
    return GlassMenu(
      trigger: GlassContainer(
        useOwnLayer: true,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        shape: LiquidRoundedSuperellipse(borderRadius: 10),
        child: Row(
          children: [
            Text('Línguas: ', style: TextStyle(fontSize: 18)),
            Expanded(
              child: Text(
                langs.map((x) => x.label).join(','),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
      ),
      items: [
        for (var item in Language.values)
          GlassMenuItem(
            title: '${langs.contains(item) ? '✔ ' : ''}${item.label}',
            onTap: () {
              var alreadyPresent = langs.contains(item);
              if (alreadyPresent) {
                ref.read(languagesProvider.notifier).state = {...langs}
                  ..remove(item);
              } else {
                ref.read(languagesProvider.notifier).state = {...langs, item};
              }
            },
            titleStyle: TextStyle(color: Colors.black),
          ),
      ],
    );
  }
}

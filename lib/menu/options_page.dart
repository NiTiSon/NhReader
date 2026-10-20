import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_providers.dart';

/// Placeholder for the options screen.
class OptionsPage extends ConsumerWidget {
  const OptionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Options')),
      body: ListView(
        children: [
          const _MenuLabel('Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto),
                  label: Text('System'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode),
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode),
                  label: Text('Dark'),
                ),
              ],
              selected: {themeMode},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  ref.read(themeModeProvider.notifier).set(selection.first),
            ),
          ),
          const _MenuLabel('Privacy'),
          SwitchListTile(
            title: const Text('Secure window'),
            subtitle: const Text(
              'Block screenshots and hide the app in the recents screen',
            ),
            value: ref.watch(secureWindowProvider),
            onChanged: (value) =>
                ref.read(secureWindowProvider.notifier).set(value),
          ),
        ],
      ),
    );
  }
}

class _MenuLabel extends StatelessWidget {
  const _MenuLabel(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(name, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}
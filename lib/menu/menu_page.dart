import 'package:flutter/material.dart';

import 'about_page.dart';
import 'options_page.dart';

/// Menu tab: account placeholder plus links to the app's utility screens.
class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        children: [
          const _AccountSelector(),
          const Divider(height: 30),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Options'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const OptionsPage()),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.policy_outlined),
            title: const Text('Licenses'),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Nh Reader',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AboutPage()),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountSelector extends StatelessWidget {
  const _AccountSelector();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const CircleAvatar(child: Icon(Icons.person)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Guest', style: theme.textTheme.titleMedium),
                Text(
                  'Account selector placeholder',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

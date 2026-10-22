import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/user.dart';
import '../settings/account.dart';
import '../settings/settings_providers.dart';
import 'about_page.dart';
import 'account_selector.dart';
import 'options_page.dart';

/// Menu tab: account picker plus links to the app's utility screens.
class MenuPage extends ConsumerWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(activeAccountProvider).valueOrNull;
    final profile = ref.watch(userProfileProvider).valueOrNull;
    return SafeArea(
      child: ListView(
        children: [
          _AccountSelector(
            account: account,
            profile: profile,
            onTap: () => showAccountSelector(context),
          ),
          ListTile(
            // Only signed-in accounts have data to edit.
            enabled: account != null,
            leading: const Icon(Icons.manage_accounts_outlined),
            title: const Text('Profile'),
            // TODO: open the account editor once it exists.
            onTap: account == null ? null : () {},
          ),
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
  const _AccountSelector({
    required this.account,
    required this.profile,
    required this.onTap,
  });

  final Account? account;
  final UserProfile? profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: AccountAvatar(url: profile?.avatarUrl ?? account?.avatarUrl),
      title: Row(
        children: [
          Flexible(
            child: Text(
              account == null ? 'Guest' : profile?.username ?? account!.label,
              style: theme.textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (account is TokenAccount) ...[
            const SizedBox(width: 8),
            const ApiTokenBadge(),
          ],
        ],
      ),
      subtitle: Text(
        account == null ? 'Tap to log in or switch account' : 'Signed in',
      ),
      trailing: const Icon(Icons.expand_more),
      onTap: onTap,
    );
  }
}

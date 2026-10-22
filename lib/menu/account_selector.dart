import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/user.dart';
import '../auth/login_page.dart';
import '../home/home_feed.dart';
import '../settings/account.dart';
import '../settings/settings_providers.dart';

/// Name and avatar of the signed-in account; null in guest mode.
final userProfileProvider = FutureProvider.autoDispose<UserProfile?>(
  (ref) async {
    final account = await ref.watch(activeAccountProvider.future);
    if (account == null) return null;
    final profile = await ref.watch(nhentaiApiProvider).me();
    try {
      // Cache with the account so the next launch can show it before (or
      // without) a network round trip.
      await ref.read(accountsProvider).setProfile(
        account.id,
        username: profile.username,
        avatarUrl: profile.avatarUrl,
      );
    } catch (_) {
      // A failed cache write must not hide the live profile.
    }
    return profile;
  },
);

/// Round account picture, falling back to a person icon when there is none.
class AccountAvatar extends StatelessWidget {
  const AccountAvatar({super.key, this.url});

  final String? url;

  static const _fallback = CircleAvatar(child: Icon(Icons.person));

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    if (url == null || url.isEmpty) return _fallback;
    return ClipOval(
      child: SizedBox.square(
        dimension: 40,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, _) => _fallback,
          errorWidget: (_, _, _) => _fallback,
        ),
      ),
    );
  }
}

class ApiTokenBadge extends StatelessWidget {
  const ApiTokenBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'API Key',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

/// Modal account switcher: guest, the stored accounts, and a log-in action.
Future<void> showAccountSelector(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _AccountSheet(),
  );
}

class _AccountSheet extends ConsumerWidget {
  const _AccountSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountListProvider);
    // Read once: a selection closes the sheet, so no live rebuild is needed.
    final activeId = ref.watch(settingsProvider).activeAccountId;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              'Accounts',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline),
                  ),
                  title: const Text('Guest'),
                  trailing: activeId == null ? const Icon(Icons.check) : null,
                  selected: activeId == null,
                  onTap: () => _activate(context, ref, null),
                ),
                ...switch (accounts) {
                  AsyncData(:final value) => [
                    for (final account in value)
                      _AccountTile(
                        account: account,
                        active: account.id == activeId,
                        onTap: () => _activate(context, ref, account.id),
                      ),
                  ],
                  AsyncError() => const [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Text("Couldn't load saved accounts"),
                    ),
                  ],
                  _ => const [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                },
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: () => _logIn(context),
                  icon: const Icon(Icons.login),
                  label: const Text('Log in'),
                ),
                TextButton(
                  onPressed: () => _useApiKey(context, ref),
                  child: const Text('Use an API key'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _activate(
    BuildContext context,
    WidgetRef ref,
    String? id,
  ) async {
    await ref.read(settingsProvider).setActiveAccountId(id);
    // Requests resolve the key per call, so this is what makes the switch
    // take effect for the next fetch.
    ref.invalidate(activeAccountProvider);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _logIn(BuildContext context) async {
    // LoginPage activates the account before popping, so just close the sheet.
    final account = await Navigator.of(context).push<Account>(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
    if (account != null && context.mounted) Navigator.of(context).pop();
  }

  Future<void> _useApiKey(BuildContext context, WidgetRef ref) async {
    final account = await showDialog<Account>(
      context: context,
      builder: (_) => const _ApiKeyDialog(),
    );
    if (account == null || !context.mounted) return;
    await ref.read(settingsProvider).setActiveAccountId(account.id);
    ref.invalidate(activeAccountProvider);
    ref.invalidate(accountListProvider);
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _AccountTile extends ConsumerWidget {
  const _AccountTile({
    required this.account,
    required this.active,
    required this.onTap,
  });

  final Account account;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = active ? ref.watch(userProfileProvider).valueOrNull : null;
    return ListTile(
      leading: AccountAvatar(url: profile?.avatarUrl ?? account.avatarUrl),
      title: Row(
        children: [
          Flexible(
            child: Text(
              profile?.username ?? account.label,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (account is TokenAccount) ...[
            const SizedBox(width: 8),
            const ApiTokenBadge(),
          ],
        ],
      ),
      trailing: active ? const Icon(Icons.check) : null,
      selected: active,
      onTap: onTap,
    );
  }
}

/// Advanced login path for API keys. Most people should use [LoginPage].
class _ApiKeyDialog extends ConsumerStatefulWidget {
  const _ApiKeyDialog();

  @override
  ConsumerState<_ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends ConsumerState<_ApiKeyDialog> {
  final _controller = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final apiKey = _controller.text.trim();
    if (apiKey.isEmpty) {
      setState(() => _error = 'Enter your API key');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final account = await ref.read(accountsProvider).add(apiKey: apiKey);
      if (mounted) Navigator.of(context).pop(account);
    } catch (_) {
      if (!mounted) return;
      // Keep the dialog open so the pasted key isn't lost.
      setState(() {
        _saving = false;
        _error = "Couldn't save the account";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Use an API key'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: true,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          labelText: 'API key',
          helperText: 'Create one in your nhentai account settings',
          errorText: _error,
        ),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Log in'),
        ),
      ],
    );
  }
}

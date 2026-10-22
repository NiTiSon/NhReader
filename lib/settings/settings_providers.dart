import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/nhentai_api.dart';
import 'account.dart';
import 'accounts_repository.dart';
import 'secure_window_channel.dart';
import 'settings_repository.dart';

/// Created before runApp; main() overrides this with a loaded instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override in main()'),
);

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

final settingsProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(sharedPreferencesProvider)),
);

final accountsProvider = Provider<AccountsRepository>(
  (ref) => AccountsRepository(ref.watch(secureStorageProvider)),
);

/// Live theme choice. Kept in a Notifier (not read straight off the
/// repository) so setting it rebuilds MaterialApp immediately, without an
/// app restart.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.read(settingsProvider).themeMode;

  Future<void> set(ThemeMode mode) async {
    state = mode; // Update the UI first, then persist.
    await ref.read(settingsProvider).setThemeMode(mode);
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

/// Live Secure Window choice. Applies FLAG_SECURE through a method channel,
/// so the toggle takes effect immediately and is re-applied on launch.
class SecureWindowNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(settingsProvider).secureWindow;

  Future<void> set(bool value) async {
    state = value; // Update the switch first, then apply + persist.
    await SecureWindowChannel.apply(value);
    await ref.read(settingsProvider).setSecureWindow(value);
  }
}

final secureWindowProvider =
    NotifierProvider<SecureWindowNotifier, bool>(SecureWindowNotifier.new);

/// Live Grid/List choice for the bookmarks tab.
class BookmarksGridNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(settingsProvider).bookmarksGrid;

  Future<void> set(bool value) async {
    state = value; // Update the UI first, then persist.
    await ref.read(settingsProvider).setBookmarksGrid(value);
  }
}

final bookmarksGridProvider =
    NotifierProvider<BookmarksGridNotifier, bool>(BookmarksGridNotifier.new);

/// Live Grid columns per row for the bookmarks tab.
class BookmarksColumnsNotifier extends Notifier<int> {
  @override
  int build() => ref.read(settingsProvider).bookmarksColumns;

  Future<void> set(int value) async {
    state = value; // Update the UI first, then persist.
    await ref.read(settingsProvider).setBookmarksColumns(value);
  }
}

final bookmarksColumnsProvider =
    NotifierProvider<BookmarksColumnsNotifier, int>(
      BookmarksColumnsNotifier.new,
    );

/// Every stored account, for the account selector.
final accountListProvider = FutureProvider.autoDispose<List<Account>>(
  (ref) => ref.watch(accountsProvider).readAll(),
);

/// The account whose credentials requests should use, or null in guest mode.
final activeAccountProvider = FutureProvider<Account?>((ref) async {
  final id = ref.watch(settingsProvider).activeAccountId;
  if (id == null) return null;
  final accounts = await ref.watch(accountsProvider).readAll();
  final matches = accounts.where((a) => a.id == id);
  return matches.isEmpty ? null : matches.first;
});

/// Resolves credentials for outgoing requests and refreshes expired sessions.
///
/// Refresh is single-flight: concurrent 401s from one expired access token
/// must not race, because the server invalidates the old refresh token as
/// soon as the first refresh succeeds.
class AccountSession {
  AccountSession(this._ref);

  final Ref _ref;
  Future<String?>? _refreshing;

  Future<String?> authorizationHeader() async {
    final account = await _ref.read(activeAccountProvider.future);
    return account?.authHeader;
  }

  Future<String?> refresh() {
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<String?> _refresh() async {
    final account = await _ref.read(activeAccountProvider.future);
    if (account is! LoggedInAccount) return null;
    try {
      final session = await NhentaiApi().refresh(account.refreshToken);
      await _ref
          .read(accountsProvider)
          .setTokens(
            account.id,
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
          );
      _ref.invalidate(activeAccountProvider);
      _ref.invalidate(accountListProvider);
      return 'User ${session.accessToken}';
    } catch (_) {
      return null;
    }
  }
}

final accountSessionProvider = Provider<AccountSession>(AccountSession.new);

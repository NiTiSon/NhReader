import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account.dart';
import 'accounts_repository.dart';
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

/// The account whose API key requests should use, or null in guest mode.
final activeAccountProvider = FutureProvider<Account?>((ref) async {
  final id = ref.watch(settingsProvider).activeAccountId;
  if (id == null) return null;
  final accounts = await ref.watch(accountsProvider).readAll();
  final matches = accounts.where((a) => a.id == id);
  return matches.isEmpty ? null : matches.first;
});

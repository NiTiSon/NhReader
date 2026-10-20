import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nh_reader/settings/accounts_repository.dart';
import 'package:nh_reader/settings/settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AccountsRepository', () {
    late AccountsRepository repo;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      repo = AccountsRepository(const FlutterSecureStorage());
    });

    test('add keeps several accounts with their own keys', () async {
      final alice = await repo.add(apiKey: 'key-a');
      final bob = await repo.add(apiKey: 'key-b');

      final accounts = await repo.readAll();
      expect(accounts.map((a) => a.id), [alice.id, bob.id]);
      expect(accounts.map((a) => a.apiKey), ['key-a', 'key-b']);
    });

    test('remove deletes only the given account', () async {
      final alice = await repo.add(apiKey: 'key-a');
      final bob = await repo.add(apiKey: 'key-b');

      await repo.remove(alice.id);

      final accounts = await repo.readAll();
      expect(accounts.single.id, bob.id);
    });

    test('concurrent adds keep every account', () async {
      await Future.wait([
        repo.add(apiKey: '1'),
        repo.add(apiKey: '2'),
        repo.add(apiKey: '3'),
      ]);

      expect((await repo.readAll()).length, 3);
    });
  });

  group('SettingsRepository', () {
    test('defaults match the app defaults', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsRepository(await SharedPreferences.getInstance());

      expect(settings.themeMode, ThemeMode.system);
      expect(settings.activeAccountId, isNull);
    });

    test('setters round-trip', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsRepository(await SharedPreferences.getInstance());

      await settings.setThemeMode(ThemeMode.light);
      await settings.setActiveAccountId('42');

      expect(settings.themeMode, ThemeMode.light);
      expect(settings.activeAccountId, '42');
    });

    test('clearing the active account removes the key', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsRepository(await SharedPreferences.getInstance());

      await settings.setActiveAccountId('42');
      await settings.setActiveAccountId(null);

      expect(settings.activeAccountId, isNull);
    });
  });
}

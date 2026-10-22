import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nh_reader/settings/account.dart';
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
      expect(
        accounts.map((a) => (a as TokenAccount).apiKey),
        ['key-a', 'key-b'],
      );
    });

    test('remove deletes only the given account', () async {
      final alice = await repo.add(apiKey: 'key-a');
      final bob = await repo.add(apiKey: 'key-b');

      await repo.remove(alice.id);

      final accounts = await repo.readAll();
      expect(accounts.single.id, bob.id);
    });

    test('setProfile caches the name and avatar with one account', () async {
      final alice = await repo.add(apiKey: 'key-a');
      final bob = await repo.add(apiKey: 'key-b');

      await repo.setProfile(
        alice.id,
        username: 'Alice',
        avatarUrl: 'https://i.nhentai.net/avatars/a.png',
      );

      final accounts = await repo.readAll();
      expect(accounts.first.username, 'Alice');
      expect(accounts.first.avatarUrl, 'https://i.nhentai.net/avatars/a.png');
      expect(accounts.last.username, isNull);
      expect(accounts.last.avatarUrl, isNull);
      expect(accounts.last.id, bob.id);
      expect((accounts.last as TokenAccount).apiKey, 'key-b');
    });

    test('concurrent adds keep every account', () async {
      await Future.wait([
        repo.add(apiKey: '1'),
        repo.add(apiKey: '2'),
        repo.add(apiKey: '3'),
      ]);

      expect((await repo.readAll()).length, 3);
    });

    test('addSession stores tokens and the cached profile', () async {
      final account = await repo.addSession(
        accessToken: 'access',
        refreshToken: 'refresh',
        username: 'Alice',
        avatarUrl: 'https://i.nhentai.net/avatars/a.png',
      );

      final stored = (await repo.readAll()).single;
      expect(stored, isA<LoggedInAccount>());
      expect(stored.id, account.id);
      expect(stored.authHeader, 'User access');
      expect(stored.username, 'Alice');
      expect(stored.avatarUrl, 'https://i.nhentai.net/avatars/a.png');
    });

    test('setTokens rotates the matching session only', () async {
      final alice = await repo.addSession(
        accessToken: 'old-access',
        refreshToken: 'old-refresh',
        username: 'Alice',
      );
      final bob = await repo.addSession(
        accessToken: 'bob-access',
        refreshToken: 'bob-refresh',
        username: 'Bob',
      );

      await repo.setTokens(
        alice.id,
        accessToken: 'new-access',
        refreshToken: 'new-refresh',
      );

      final accounts = await repo.readAll();
      final updated = accounts.first as LoggedInAccount;
      expect(updated.accessToken, 'new-access');
      expect(updated.refreshToken, 'new-refresh');
      expect(updated.username, 'Alice');
      final untouched = accounts.last as LoggedInAccount;
      expect(untouched.id, bob.id);
      expect(untouched.accessToken, 'bob-access');
    });
  });

  group('Account', () {
    test('legacy api-key entries load as token accounts', () {
      final account = Account.fromJson({
        'id': '1',
        'apiKey': 'key-abcd',
        'username': 'Alice',
        'avatarUrl': 'https://i.nhentai.net/avatars/a.png',
      });

      expect(account, isA<TokenAccount>());
      expect(account.authHeader, 'Key key-abcd');
      expect(account.label, 'Alice');
    });

    test('decoding a logged-in account keeps its tokens', () {
      final decoded = Account.fromJson({
        'type': 'loggedIn',
        'id': '2',
        'accessToken': 'access',
        'refreshToken': 'refresh',
        'username': 'Alice',
        'avatarUrl': 'https://i.nhentai.net/avatars/a.png',
      });

      final account = decoded as LoggedInAccount;
      expect(account.accessToken, 'access');
      expect(account.refreshToken, 'refresh');
      expect(account.authHeader, 'User access');
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

    test('secure window is off by default and round-trips', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsRepository(await SharedPreferences.getInstance());

      expect(settings.secureWindow, isFalse);

      await settings.setSecureWindow(true);
      expect(settings.secureWindow, isTrue);

      await settings.setSecureWindow(false);
      expect(settings.secureWindow, isFalse);
    });
  });
}

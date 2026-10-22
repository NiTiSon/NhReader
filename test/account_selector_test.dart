import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nh_reader/api/nhentai_api.dart';
import 'package:nh_reader/api/user.dart';
import 'package:nh_reader/home/home_feed.dart';
import 'package:nh_reader/main.dart';
import 'package:nh_reader/menu/account_selector.dart';
import 'package:nh_reader/settings/account.dart';
import 'package:nh_reader/settings/accounts_repository.dart';
import 'package:nh_reader/settings/settings_providers.dart';

import 'helpers/app_harness.dart';

const _profile = UserProfile(
  username: 'Alice',
  avatarUrl: 'https://i.nhentai.net/avatars/alice.png',
);

class _FakeNhentaiApi extends NhentaiApi {
  @override
  Future<UserProfile> me() async => _profile;
}

Future<void> _pumpApp(WidgetTester tester) => pumpApp(
  tester,
  overrides: [nhentaiApiProvider.overrideWithValue(_FakeNhentaiApi())],
);

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('relative avatar urls resolve against the image host', () {
    final profile = UserProfile.fromJson({
      'id': 1,
      'username': 'Alice',
      'avatar_url': 'avatars/1.png?_=abc',
    });

    expect(profile.avatarUrl, 'https://i.nhentai.net/avatars/1.png?_=abc');
  });

  testWidgets('profile opens the selector and switches to a saved account', (
    tester,
  ) async {
    final account = await AccountsRepository(const FlutterSecureStorage())
        .add(apiKey: 'key-abcd');
    await _pumpApp(tester);

    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guest'));
    await tester.pumpAndSettle();

    expect(find.text('Accounts'), findsOneWidget);
    expect(find.text(account.maskedKey), findsOneWidget);
    expect(find.text('API Key'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(
      tester.widget<ListTile>(find.widgetWithText(ListTile, 'Profile')).enabled,
      isFalse,
    );

    await tester.tap(find.text(account.maskedKey));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(NhReaderApp)),
    );
    expect(container.read(settingsProvider).activeAccountId, account.id);
    expect(find.text('Accounts'), findsNothing);
    // Signed-in header shows the fetched name and avatar, not the key hint.
    expect(find.text(_profile.username), findsOneWidget);
    final avatar = tester.widget<CachedNetworkImage>(
      find.descendant(
        of: find.byType(AccountAvatar),
        matching: find.byType(CachedNetworkImage),
      ),
    );
    expect(avatar.imageUrl, _profile.avatarUrl);
    expect(
      tester.widget<ListTile>(find.widgetWithText(ListTile, 'Profile')).enabled,
      isTrue,
    );

    // The profile is cached with the account for the next launch.
    final cached = (await AccountsRepository(
      const FlutterSecureStorage(),
    ).readAll()).single;
    expect(cached.username, _profile.username);
    expect(cached.avatarUrl, _profile.avatarUrl);
  });

  testWidgets('log in opens the username and password form', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guest'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Username or email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    // Back on the account sheet, not signed in.
    expect(find.text('Accounts'), findsOneWidget);
  });

  testWidgets('adding an API key stores and activates the account', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guest'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use an API key'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'key-wxyz');
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Log in'),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(NhReaderApp)),
    );
    final stored = await container.read(accountsProvider).readAll();
    expect((stored.single as TokenAccount).apiKey, 'key-wxyz');
    expect(container.read(settingsProvider).activeAccountId, stored.single.id);
    expect(find.text(_profile.username), findsOneWidget);
    expect(stored.single.username, _profile.username);
    expect(stored.single.avatarUrl, _profile.avatarUrl);
  });
}

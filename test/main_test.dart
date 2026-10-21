import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nh_reader/main.dart';
import 'package:nh_reader/settings/settings_providers.dart';

import 'helpers/app_harness.dart';

void main() {
  testWidgets('app renders with the three-tab navigation bar', (tester) async {
    await pumpApp(tester);

    final navBar = find.byType(NavigationBar);
    expect(navBar, findsOneWidget);
    for (final label in ['Bookmarks', 'Home', 'Menu']) {
      expect(
        find.descendant(of: navBar, matching: find.text(label)),
        findsOneWidget,
      );
    }
  });

  testWidgets('tapping Menu opens the menu tab', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();

    expect(find.text('Options'), findsOneWidget);
    expect(find.text('Licenses'), findsOneWidget);
  });

  testWidgets('choosing a theme in Options applies it without a restart', (
    tester,
  ) async {
    await pumpApp(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(NhReaderApp)),
    );

    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Options'));
    await tester.pumpAndSettle();

    expect(container.read(themeModeProvider), ThemeMode.system);

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();

    // Same widget tree, new theme: no restart/reload happened.
    expect(container.read(themeModeProvider), ThemeMode.light);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);
    expect(app.theme!.brightness, Brightness.light);
  });

  testWidgets('toggling Secure window flips the switch', (tester) async {
    await pumpApp(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(NhReaderApp)),
    );

    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Options'));
    await tester.pumpAndSettle();

    expect(container.read(secureWindowProvider), isFalse);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(container.read(secureWindowProvider), isTrue);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });
}

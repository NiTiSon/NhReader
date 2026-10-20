import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nh_reader/main.dart';

void main() {
  testWidgets('app renders with the three-tab navigation bar', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: NhReaderApp()),
    );

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
    await tester.pumpWidget(
      const ProviderScope(child: NhReaderApp()),
    );

    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();

    expect(find.text('Options'), findsOneWidget);
    expect(find.text('Licenses'), findsOneWidget);
  });
}

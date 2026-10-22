import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nh_reader/api/gallery.dart';
import 'package:nh_reader/api/nhentai_api.dart';
import 'package:nh_reader/api/user.dart';
import 'package:nh_reader/bookmarks/bookmarks_page.dart';
import 'package:nh_reader/home/home_feed.dart';
import 'package:nh_reader/settings/account.dart';
import 'package:nh_reader/settings/settings_providers.dart';
import 'package:nh_reader/widgets/gallery_cover.dart';

import 'helpers/app_harness.dart';

class _FakeApi extends NhentaiApi {
  _FakeApi({this.numPages = 1});

  final int numPages;
  final queries = <String?>[];
  final pages = <int>[];

  static GalleryListItem item(int id) => GalleryListItem(
    id: id,
    mediaId: 'm$id',
    englishTitle: 'Gallery $id',
    thumbnail: '/galleries/$id/cover.jpg',
    thumbnailWidth: 240,
    thumbnailHeight: 340,
    numPages: 20,
    numFavorites: 12,
  );

  @override
  Future<PaginatedGalleries> favorites({String? q, int page = 1}) async {
    queries.add(q);
    pages.add(page);
    final items = page == 1
        ? [item(0), item(1), item(2), item(3)]
        : [item(100 + page)];
    final filtered = q == null
        ? items
        : items
              .where(
                (g) => g.displayTitle.toLowerCase().contains(q.toLowerCase()),
              )
              .toList();
    return PaginatedGalleries(
      items: filtered,
      numPages: numPages,
      perPage: 25,
      total: filtered.length,
    );
  }

  @override
  Future<List<String>> thumbServers() async => const ['https://t1.nhentai.net'];

  @override
  Future<UserProfile> me() async =>
      const UserProfile(username: 'Alice', avatarUrl: '');
}

List<Override> _signedIn(NhentaiApi api) {
  final account = TokenAccount.create(apiKey: 'key');
  return [
    nhentaiApiProvider.overrideWithValue(api),
    activeAccountProvider.overrideWith((ref) async => account),
  ];
}

Future<void> _openBookmarks(WidgetTester tester) async {
  await tester.tap(find.text('Bookmarks'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('bookmarks shows favorites and the top bar controls', (
    tester,
  ) async {
    final api = _FakeApi();
    await pumpApp(tester, overrides: _signedIn(api));
    await _openBookmarks(tester);

    final page = find.byType(BookmarksPage);
    expect(find.text('Gallery 0'), findsOneWidget);
    expect(
      find.descendant(of: page, matching: find.byIcon(Icons.search)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: page, matching: find.byIcon(Icons.settings_outlined)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: page, matching: find.byIcon(Icons.shuffle)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: page, matching: find.byType(SliverGrid)),
      findsOneWidget,
    );
  });

  testWidgets('guest is asked to log in', (tester) async {
    await pumpApp(tester);
    await _openBookmarks(tester);

    expect(find.text('Log in to see your bookmarks'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });

  testWidgets('grid/list switch updates and persists', (tester) async {
    final api = _FakeApi();
    await pumpApp(tester, overrides: _signedIn(api));
    await _openBookmarks(tester);

    final page = find.byType(BookmarksPage);
    await tester.tap(
      find.descendant(of: page, matching: find.byIcon(Icons.settings_outlined)),
    );
    await tester.pumpAndSettle();
    expect(find.text('View settings'), findsOneWidget);

    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(BookmarksPage)),
    );
    expect(container.read(bookmarksGridProvider), isFalse);
    expect(container.read(settingsProvider).bookmarksGrid, isFalse);
    expect(
      find.descendant(of: page, matching: find.byType(SliverList)),
      findsOneWidget,
    );

    final ratio = tester.widget<AspectRatio>(
      find.descendant(of: page, matching: find.byType(AspectRatio)).first,
    );
    expect(ratio.aspectRatio, closeTo(240 / 340, 0.001));
    final coverSize = tester.getSize(
      find.descendant(of: page, matching: find.byType(GalleryCover)).first,
    );
    expect(coverSize.width, 64);
    expect(coverSize.height, closeTo(64 * 340 / 240, 0.01));
  });

  testWidgets('grid columns setting updates the layout and persists', (
    tester,
  ) async {
    final api = _FakeApi();
    await pumpApp(tester, overrides: _signedIn(api));
    await _openBookmarks(tester);

    final page = find.byType(BookmarksPage);
    await tester.tap(
      find.descendant(
        of: page,
        matching: find.byIcon(Icons.settings_outlined),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Columns per row'), findsOneWidget);

    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(BookmarksPage)),
    );
    expect(container.read(bookmarksColumnsProvider), 2);
    expect(container.read(settingsProvider).bookmarksColumns, 2);
    final grid = tester.widget<SliverGrid>(
      find.descendant(of: page, matching: find.byType(SliverGrid)),
    );
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2);
  });

  testWidgets('search is sent to favorites after a short pause', (
    tester,
  ) async {
    final api = _FakeApi();
    await pumpApp(tester, overrides: _signedIn(api));
    await _openBookmarks(tester);

    await tester.enterText(find.byType(TextField), 'Gallery 3');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(api.queries.last, 'Gallery 3');
    expect(find.text('Gallery 0'), findsNothing);
    expect(find.text('Gallery 3'), findsWidgets);
  });

  testWidgets('load more appends the next page', (tester) async {
    final api = _FakeApi(numPages: 2);
    await pumpApp(tester, overrides: _signedIn(api));
    await _openBookmarks(tester);

    expect(find.text('Gallery 102'), findsNothing);
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();

    expect(find.text('Gallery 102'), findsOneWidget);
    expect(api.pages, [1, 2]);
  });
}

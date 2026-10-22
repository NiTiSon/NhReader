import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nh_reader/api/gallery.dart';
import 'package:nh_reader/api/nhentai_api.dart';
import 'package:nh_reader/api/user.dart';
import 'package:nh_reader/bookmarks/bookmarks_feed.dart';
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
    final start = page == 1 ? 0 : page * 100;
    final items = [for (var i = start; i < start + 25; i++) item(i)];
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
      find.descendant(of: page, matching: find.byIcon(Icons.settings_outlined)),
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

  testWidgets('sort by date switches ends of the favorites list', (
    tester,
  ) async {
    final api = _FakeApi(numPages: 2);
    await pumpApp(tester, overrides: _signedIn(api));
    await _openBookmarks(tester);

    final page = find.byType(BookmarksPage);
    await tester.tap(
      find.descendant(of: page, matching: find.byIcon(Icons.settings_outlined)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Oldest first'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(BookmarksPage)),
    );
    expect(container.read(bookmarksNewestFirstProvider), isFalse);
    expect(container.read(settingsProvider).bookmarksNewestFirst, isFalse);
    expect(api.pages, [1, 1, 2]);

    var feed = container.read(bookmarksProvider).valueOrNull!;
    expect(feed.items.first.id, 224);
    expect(feed.items.last.id, 200);
    expect(feed.page, 2);

    await tester.tap(find.text('Newest first'));
    await tester.pumpAndSettle();

    expect(container.read(bookmarksNewestFirstProvider), isTrue);
    feed = container.read(bookmarksProvider).valueOrNull!;
    expect(feed.items.first.id, 0);
    expect(feed.items.last.id, 24);
    expect(feed.page, 1);
  });

  testWidgets('reaching the end loads the next page', (tester) async {
    final api = _FakeApi(numPages: 2);
    await pumpApp(tester, overrides: _signedIn(api));
    await _openBookmarks(tester);

    expect(api.pages, [1]);
    expect(find.text('Gallery 200'), findsNothing);

    final scroll = find.descendant(
      of: find.byType(BookmarksPage),
      matching: find.byType(CustomScrollView),
    );
    await tester.drag(scroll, const Offset(0, -3000));
    await tester.pumpAndSettle();

    expect(api.pages, [1, 2]);
    await tester.drag(scroll, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Gallery 200'), findsOneWidget);
  });
}

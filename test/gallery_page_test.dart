import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nh_reader/api/gallery.dart';
import 'package:nh_reader/api/nhentai_api.dart';
import 'package:nh_reader/gallery/gallery_page.dart';
import 'package:nh_reader/gallery/gallery_provider.dart';
import 'package:nh_reader/home/home_feed.dart';
import 'package:nh_reader/settings/account.dart';
import 'package:nh_reader/settings/settings_providers.dart';

import 'helpers/app_harness.dart';

GalleryPageData _data() {
  return GalleryPageData(
    coverUrl: '',
    detail: GalleryDetail(
      id: 7,
      mediaId: 'm7',
      title: const GalleryTitle(
        english: 'Gallery One',
        pretty: 'Gallery One',
        japanese: 'ギャラリー',
      ),
      cover: const CoverInfo(
        path: '/galleries/7/cover.jpg',
        width: 240,
        height: 340,
      ),
      uploadDate: DateTime(2014, 5, 1).millisecondsSinceEpoch ~/ 1000,
      numPages: 28,
      numFavorites: 1234,
      tags: [
        const GalleryTag(
          id: 1,
          type: 'category',
          name: 'doujinshi',
          slug: 'doujinshi',
        ),
        const GalleryTag(
          id: 2,
          type: 'language',
          name: 'english',
          slug: 'english',
        ),
        const GalleryTag(
          id: 17,
          type: 'language',
          name: 'translated',
          slug: 'translated',
        ),
        const GalleryTag(
          id: 3,
          type: 'artist',
          name: 'WindArt',
          slug: 'windart',
        ),
        const GalleryTag(
          id: 4,
          type: 'tag',
          name: 'romance',
          slug: 'romance',
          count: 125500,
        ),
        for (var i = 5; i < 16; i++)
          GalleryTag(id: i, type: 'tag', name: 'tag $i', slug: 'tag-$i'),
        const GalleryTag(
          id: 16,
          type: 'parody',
          name: 'Touhou Project',
          slug: 'touhou-project',
          count: 158239,
        ),
      ],
    ),
  );
}

Future<void> _pumpGallery(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        galleryPageProvider.overrideWith((ref, id) => _data()),
        ...overrides,
      ],
      child: const MaterialApp(home: GalleryPage(id: 7)),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeApi extends NhentaiApi {
  @override
  Future<GalleryDetail> galleryDetail(int id) async => _data().detail;

  @override
  Future<List<String>> thumbServers() async => [
    'https://t1.nhentai.net',
    'https://t2.nhentai.net',
  ];

  @override
  Future<FavoriteResult> setFavorite(int id, bool favorited) async {
    return FavoriteResult(
      favorited: favorited,
      numFavorites: favorited ? 1500 : 1234,
    );
  }
}

void main() {
  test('gallery covers use the thumbnail CDN', () async {
    final container = ProviderContainer(
      overrides: [nhentaiApiProvider.overrideWithValue(_FakeApi())],
    );
    addTearDown(container.dispose);
    final sub = container.listen(galleryPageProvider(7), (_, _) {});
    addTearDown(sub.close);

    final data = await container.read(galleryPageProvider(7).future);

    expect(data.coverUrl, 'https://t2.nhentai.net/galleries/7/cover.jpg');
  });

  testWidgets('title page shows metadata, creator, and tag preview', (
    tester,
  ) async {
    await _pumpGallery(tester);

    expect(find.text('Gallery One'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsNothing);
    expect(find.text('Type'), findsNothing);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Doujinshi'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Translated'), findsNothing);
    expect(find.text('Comments'), findsOneWidget);
    expect(find.text('28'), findsOneWidget);
    expect(find.text('1.2K'), findsNWidgets(2));
    expect(find.text('2014'), findsOneWidget);
    expect(find.text('WindArt'), findsOneWidget);
    expect(find.text('18+'), findsNothing);
    expect(find.text('#romance'), findsNothing);
    expect(find.text('romance'), findsOneWidget);
    expect(find.text('125.5k'), findsOneWidget);
    expect(find.textContaining('|'), findsNothing);
    expect(find.text('+ 3 more'), findsOneWidget);
  });

  testWidgets('tags tab groups the full tag list', (tester) async {
    await _pumpGallery(tester);

    await tester.tap(find.text('Tags'));
    await tester.pumpAndSettle();

    expect(find.text('CATEGORIES'), findsOneWidget);
    expect(find.text('LANGUAGES'), findsOneWidget);
    expect(find.text('GENERAL'), findsOneWidget);
    expect(find.text('PARODIES'), findsOneWidget);
    expect(find.text('ARTISTS'), findsOneWidget);
    expect(find.text('doujinshi'), findsOneWidget);
    expect(find.text('english'), findsOneWidget);
    expect(find.text('translated'), findsOneWidget);
    expect(find.text('WindArt'), findsOneWidget);
    expect(find.text('Touhou Project'), findsOneWidget);
    expect(find.text('158.2k'), findsOneWidget);
    expect(find.textContaining('|'), findsNothing);
    expect(find.text('18+'), findsNothing);
  });

  testWidgets('comments tab shows the placeholder', (tester) async {
    await _pumpGallery(tester);

    await tester.tap(find.text('Comments'));
    await tester.pumpAndSettle();

    expect(find.text('Comments coming soon.'), findsOneWidget);
    expect(find.text('GENERAL'), findsNothing);
  });

  testWidgets('the more chip switches to the tags tab', (tester) async {
    await _pumpGallery(tester);

    await tester.ensureVisible(find.text('+ 3 more'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ 3 more'));
    await tester.pumpAndSettle();

    expect(find.text('GENERAL'), findsOneWidget);
  });

  testWidgets('favoriting updates the button and both counts', (tester) async {
    await _pumpGallery(
      tester,
      overrides: [
        nhentaiApiProvider.overrideWithValue(_FakeApi()),
        activeAccountProvider.overrideWith(
          (ref) async => TokenAccount.create(apiKey: 'key'),
        ),
      ],
    );

    await tester.tap(find.text('Favorite'));
    await tester.pumpAndSettle();

    expect(find.text('Favorited'), findsOneWidget);
    expect(find.text('1.5K'), findsNWidgets(2));
  });

  testWidgets('a failed detail load shows Retry and refetches', (tester) async {
    var attempts = 0;
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          galleryPageProvider.overrideWith((ref, id) async {
            attempts++;
            throw Exception('offline');
          }),
        ],
        child: const MaterialApp(home: GalleryPage(id: 7)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load this title"), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
  });

  testWidgets('tapping a home cover opens the title page', (tester) async {
    await pumpApp(
      tester,
      overrides: [galleryPageProvider.overrideWith((ref, id) => _data())],
    );

    await tester.tap(find.text('Gallery 0'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(GalleryPage), findsOneWidget);
    expect(find.text('Gallery One'), findsOneWidget);
  });
}

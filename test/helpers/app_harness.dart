import 'dart:ui' show Size;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nh_reader/api/gallery.dart';
import 'package:nh_reader/home/home_feed.dart';
import 'package:nh_reader/main.dart';
import 'package:nh_reader/settings/settings_providers.dart';

/// Builds a feed that never touches the network. Servers and paths are laid
/// out so thumbnailUrl() can be asserted on in tests.
HomeFeed fakeHomeFeed({int popularCount = 3, int newUploadsCount = 6}) {
  GalleryListItem item(int id) => GalleryListItem(
    id: id,
    mediaId: 'm$id',
    englishTitle: 'Gallery $id',
    thumbnail: '/galleries/$id/cover.jpg',
    thumbnailWidth: 240,
    thumbnailHeight: 340,
    numFavorites: 1234,
  );

  return HomeFeed(
    servers: const ['https://t1.nhentai.net'],
    popular: List.generate(popularCount, (i) => item(i)),
    newUploads: PaginatedGalleries(
      items: List.generate(newUploadsCount, (i) => item(100 + i)),
      numPages: 1,
      perPage: newUploadsCount,
      total: newUploadsCount,
    ),
  );
}

/// Pumps the app with prefs overridden and the feed stubbed out, so widget
/// tests never hit the network.
Future<void> pumpApp(
  WidgetTester tester, {
  Future<HomeFeed> Function()? feed,
}) async {
  // Phone-sized surface so layout-dependent tests match a real device.
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final feedFactory = feed ?? (() async => fakeHomeFeed());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        homeFeedProvider.overrideWith((_) => feedFactory()),
      ],
      child: const NhReaderApp(),
    ),
  );
  // Let the stubbed feed future resolve so tests never assert mid-load.
  await tester.pumpAndSettle();
}

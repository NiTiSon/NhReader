import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nh_reader/api/gallery.dart';
import 'package:nh_reader/home/home_feed.dart';

import 'helpers/app_harness.dart';

void main() {
  testWidgets('home shows the Popular Now carousel and New Uploads grid', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Popular Now'), findsOneWidget);
    expect(find.text('New Uploads'), findsOneWidget);
    // The first carousel card renders its title.
    expect(find.text('Gallery 0'), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsWidgets);
  });

  testWidgets('thumbnails join a CDN server with the relative path', (
    tester,
  ) async {
    await pumpApp(tester);

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage).first,
    );
    expect(image.imageUrl, 'https://t1.nhentai.net/galleries/0/cover.jpg');
  });

  testWidgets('popular cards are a little larger than the grid tiles', (
    tester,
  ) async {
    await pumpApp(tester);

    // The harness surface is 400 wide: a grid tile is (400 - 24 - 16) / 3.
    final popular = tester.getSize(find.byType(CachedNetworkImage).first);
    final grid = tester.getSize(find.byType(CachedNetworkImage).last);

    expect(popular.width, grid.width * 1.12);
    expect(popular.width, greaterThan(grid.width));
    // Same cover proportions as the grid, so it grows both ways.
    expect(popular.width / popular.height, closeTo(0.68, 0.01));
    expect(popular.height, greaterThan(grid.height));
  });

  testWidgets('an empty feed shows an empty state', (tester) async {
    await pumpApp(
      tester,
      feed: () async => HomeFeed(
        servers: const ['https://t1.nhentai.net'],
        popular: const [],
        newUploads: PaginatedGalleries(items: const [], numPages: 0),
      ),
    );

    expect(find.text('Nothing to show right now'), findsOneWidget);
    expect(find.text('Popular Now'), findsNothing);
  });

  testWidgets('a failed feed shows Retry, and Retry refetches', (tester) async {
    var attempts = 0;
    await pumpApp(
      tester,
      feed: () async {
        attempts++;
        throw Exception('offline');
      },
    );

    expect(find.text("Couldn't load the feed"), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    // The failure repeats here, which is what proves the refetch ran.
    expect(attempts, 2);
    expect(find.text("Couldn't load the feed"), findsOneWidget);
  });
}

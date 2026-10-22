import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/gallery.dart';
import '../api/nhentai_api.dart';
import '../settings/settings_providers.dart';

/// Everything the home screen needs from one refresh, fetched concurrently.
class HomeFeed {
  const HomeFeed({
    required this.servers,
    required this.popular,
    required this.newUploads,
  });

  final List<String> servers;
  final List<GalleryListItem> popular;
  final PaginatedGalleries newUploads;

  String thumbnailUrl(GalleryListItem gallery) =>
      cdnThumbnailUrl(servers, gallery);
}

/// Anonymous requests are allowed, but attaching the active account
/// raises the `/galleries` rate limit and personalizes the results.
final nhentaiApiProvider = Provider<NhentaiApi>((ref) {
  final session = ref.watch(accountSessionProvider);
  return NhentaiApi(
    authorizationProvider: session.authorizationHeader,
    refreshAuthorization: session.refresh,
  );
});

final homeFeedProvider = FutureProvider<HomeFeed>((ref) async {
  final api = ref.watch(nhentaiApiProvider);
  // shortcut: only the first page of New Uploads (25 items); add paging when
  // the grid needs infinite scroll.
  final (popular, newUploads, servers) = await (
    api.popular(),
    api.newUploads(),
    api.thumbServers(),
  ).wait;

  return HomeFeed(
    servers: servers,
    popular: popular.where((g) => !g.blacklisted).toList(),
    newUploads: PaginatedGalleries(
      items: newUploads.items.where((g) => !g.blacklisted).toList(),
      numPages: newUploads.numPages,
      perPage: newUploads.perPage,
      total: newUploads.total,
    ),
  );
});

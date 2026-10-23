import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/gallery.dart';
import '../home/home_feed.dart';
import '../settings/settings_providers.dart';

/// The signed-in user's favorite galleries, plus the CDN servers needed to
/// render their covers.
class BookmarksFeed {
  const BookmarksFeed({
    required this.items,
    required this.servers,
    required this.page,
    required this.numPages,
    this.guest = false,
    this.loadingMore = false,
    this.moreError = false,
    this.newestFirst = true,
  });

  const BookmarksFeed.guest()
    : items = const [],
      servers = const [],
      page = 0,
      numPages = 0,
      guest = true,
      loadingMore = false,
      moreError = false,
      newestFirst = true;

  final List<GalleryListItem> items;
  final List<String> servers;
  final int page;
  final int numPages;
  final bool guest;
  final bool loadingMore;
  final bool moreError;
  final bool newestFirst;

  bool get hasMore => newestFirst ? page < numPages : page > 1;

  int get nextPage => newestFirst ? page + 1 : page - 1;

  BookmarksFeed copyWith({
    List<GalleryListItem>? items,
    int? page,
    int? numPages,
    bool? loadingMore,
    bool? moreError,
  }) {
    return BookmarksFeed(
      items: items ?? this.items,
      servers: servers,
      page: page ?? this.page,
      numPages: numPages ?? this.numPages,
      guest: guest,
      loadingMore: loadingMore ?? this.loadingMore,
      moreError: moreError ?? this.moreError,
      newestFirst: newestFirst,
    );
  }
}

/// Server-side search text for bookmarks. The page updates this after a short
/// pause so typing does not spend the endpoint's small rate limit.
final bookmarksQueryProvider = StateProvider<String>((ref) => '');

final bookmarksProvider =
    AutoDisposeAsyncNotifierProvider<BookmarksNotifier, BookmarksFeed>(
      BookmarksNotifier.new,
    );

class BookmarksNotifier extends AutoDisposeAsyncNotifier<BookmarksFeed> {
  @override
  Future<BookmarksFeed> build() async {
    // Watch every dependency before awaiting so query/account changes always
    // rebuild the feed.
    final accountFuture = ref.watch(activeAccountProvider.future);
    final query = ref.watch(bookmarksQueryProvider).trim();
    final newestFirst = ref.watch(bookmarksNewestFirstProvider);
    final api = ref.watch(nhentaiApiProvider);
    final serversFuture = ref.watch(galleryCoverServersProvider.future);

    final account = await accountFuture;
    if (account == null) return const BookmarksFeed.guest();

    final (firstPage, servers) = await (
      api.favorites(q: query.isEmpty ? null : query),
      serversFuture,
    ).wait;

    // The endpoint only pages newest-first. Oldest-first starts at the last
    // page and walks backwards, reversing each page.
    final lastPageNumber = firstPage.numPages;
    final page = !newestFirst && lastPageNumber > 1
        ? await api.favorites(
            q: query.isEmpty ? null : query,
            page: lastPageNumber,
          )
        : firstPage;

    return BookmarksFeed(
      items: _visible(page, newestFirst),
      servers: servers,
      page: newestFirst ? 1 : lastPageNumber,
      numPages: page.numPages,
      newestFirst: newestFirst,
    );
  }

  List<GalleryListItem> _visible(PaginatedGalleries page, bool newestFirst) {
    final items = page.items.where((g) => !g.blacklisted).toList();
    return newestFirst ? items : items.reversed.toList();
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null ||
        current.guest ||
        current.loadingMore ||
        !current.hasMore) {
      return;
    }

    final loading = current.copyWith(loadingMore: true, moreError: false);
    state = AsyncData(loading);

    final query = ref.read(bookmarksQueryProvider).trim();
    final page = current.nextPage;
    try {
      final favorites = await ref
          .read(nhentaiApiProvider)
          .favorites(q: query.isEmpty ? null : query, page: page);
      // A query/account change may have started a new build while this page
      // was in flight; do not overwrite its newer state.
      if (state.valueOrNull != loading) return;
      state = AsyncData(
        loading.copyWith(
          items: [
            ...loading.items,
            ..._visible(favorites, loading.newestFirst),
          ],
          page: page,
          numPages: favorites.numPages,
          loadingMore: false,
        ),
      );
    } catch (_) {
      if (state.valueOrNull != loading) return;
      state = AsyncData(loading.copyWith(loadingMore: false, moreError: true));
    }
  }
}

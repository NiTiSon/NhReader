import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/gallery.dart';
import '../menu/account_selector.dart';
import '../settings/settings_providers.dart';
import '../widgets/gallery_cover.dart';
import 'bookmarks_feed.dart';

/// Bookmarks tab: the signed-in user's nhentai favorites.
class BookmarksPage extends ConsumerStatefulWidget {
  const BookmarksPage({super.key});

  @override
  ConsumerState<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends ConsumerState<BookmarksPage> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _loadMoreScheduled = false;

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(bookmarksQueryProvider);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(bookmarksProvider);
    final grid = ref.watch(bookmarksGridProvider);
    final columns = ref.watch(bookmarksColumnsProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          onSubmitted: _applyQuery,
          textInputAction: TextInputAction.search,
          autocorrect: false,
          decoration: InputDecoration(
            hintText: 'Search bookmarks',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close),
                    onPressed: _clearSearch,
                  ),
            isDense: true,
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'View settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _showSettings,
          ),
          IconButton(
            tooltip: 'Random bookmark',
            icon: const Icon(Icons.shuffle),
            // TODO: open /api/v2/favorites/random once a gallery page exists.
            onPressed: null,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(bookmarksProvider.future),
        child: switch (feed) {
          AsyncData(:final value) => _body(value, grid, columns),
          AsyncError() => _BookmarksMessage(
            icon: Icons.cloud_off,
            message: "Couldn't load bookmarks",
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(bookmarksProvider),
          ),
          _ => const _BookmarksLoading(),
        },
      ),
    );
  }

  Widget _body(BookmarksFeed feed, bool grid, int columns) {
    if (feed.guest) {
      return _BookmarksMessage(
        icon: Icons.bookmark_border,
        message: 'Log in to see your bookmarks',
        actionLabel: 'Log in',
        onAction: () => showAccountSelector(context),
      );
    }

    if (feed.items.isEmpty) {
      final hasQuery = _searchController.text.trim().isNotEmpty;
      return _BookmarksMessage(
        icon: hasQuery ? Icons.search_off : Icons.bookmark_border,
        message: hasQuery
            ? 'No bookmarks match your search'
            : 'No bookmarks yet',
        actionLabel: hasQuery ? 'Clear search' : null,
        onAction: hasQuery ? _clearSearch : null,
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (grid)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.68,
              ),
              delegate: SliverChildBuilderDelegate((context, i) {
                if (i == feed.items.length - 1) _scheduleLoadMore(feed);
                final gallery = feed.items[i];
                return _BookmarkTile(
                  gallery: gallery,
                  url: cdnThumbnailUrl(feed.servers, gallery),
                );
              }, childCount: feed.items.length),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, i) {
                if (i == feed.items.length - 1) _scheduleLoadMore(feed);
                final gallery = feed.items[i];
                return _BookmarkRow(
                  gallery: gallery,
                  url: cdnThumbnailUrl(feed.servers, gallery),
                );
              }, childCount: feed.items.length),
            ),
          ),
        if (feed.loadingMore || feed.moreError)
          SliverToBoxAdapter(
            child: _LoadMoreFooter(
              feed: feed,
              onPressed: () => ref.read(bookmarksProvider.notifier).loadMore(),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) _applyQuery(value);
    });
  }

  void _applyQuery(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    if (query == ref.read(bookmarksQueryProvider)) return;
    ref.read(bookmarksQueryProvider.notifier).state = query;
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {});
    _applyQuery('');
  }

  void _scheduleLoadMore(BookmarksFeed feed) {
    if (_loadMoreScheduled ||
        feed.loadingMore ||
        feed.moreError ||
        !feed.hasMore) {
      return;
    }
    _loadMoreScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMoreScheduled = false;
      if (!mounted) return;
      final state = ref.read(bookmarksProvider);
      final current = state.valueOrNull;
      if (state is! AsyncData<BookmarksFeed> ||
          current == null ||
          current.guest ||
          current.loadingMore ||
          current.moreError ||
          !current.hasMore) {
        return;
      }
      ref.read(bookmarksProvider.notifier).loadMore();
    });
  }

  Future<void> _showSettings() {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _BookmarksSettingsSheet(),
    );
  }
}

class _BookmarksSettingsSheet extends ConsumerWidget {
  const _BookmarksSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = ref.watch(bookmarksGridProvider);
    final columns = ref.watch(bookmarksColumnsProvider);
    final newestFirst = ref.watch(bookmarksNewestFirstProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'View settings',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.grid_view),
                  label: Text('Grid'),
                ),
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.view_list),
                  label: Text('List'),
                ),
              ],
              selected: {grid},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  ref.read(bookmarksGridProvider.notifier).set(selection.first),
            ),
            const SizedBox(height: 20),
            Text(
              'Columns per row',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 2, label: Text('2')),
                ButtonSegment(value: 3, label: Text('3')),
                ButtonSegment(value: 4, label: Text('4')),
              ],
              selected: {columns},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => ref
                  .read(bookmarksColumnsProvider.notifier)
                  .set(selection.first),
            ),
            const SizedBox(height: 20),
            Text('Sort by date', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Newest first')),
                ButtonSegment(value: false, label: Text('Oldest first')),
              ],
              selected: {newestFirst},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => ref
                  .read(bookmarksNewestFirstProvider.notifier)
                  .set(selection.first),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookmarkTile extends StatelessWidget {
  const _BookmarkTile({required this.gallery, required this.url});

  final GalleryListItem gallery;
  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          GalleryCover(url: url),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.55, 1],
                colors: [Colors.transparent, Colors.black87],
              ),
            ),
          ),
          Positioned(
            left: 6,
            right: 6,
            bottom: 6,
            child: Text(
              gallery.displayTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookmarkRow extends StatelessWidget {
  const _BookmarkRow({required this.gallery, required this.url});

  final GalleryListItem gallery;
  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = gallery.thumbnailWidth;
    final height = gallery.thumbnailHeight;
    final aspectRatio = width > 0 && height > 0 ? width / height : 0.68;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: GalleryCover(url: url),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gallery.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  '${gallery.numPages} pages',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({required this.feed, required this.onPressed});

  final BookmarksFeed feed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: feed.loadingMore
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(onPressed: onPressed, child: const Text('Retry')),
      ),
    );
  }
}

class _BookmarksLoading extends StatelessWidget {
  const _BookmarksLoading();

  @override
  Widget build(BuildContext context) {
    return const CustomScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }
}

class _BookmarksMessage extends StatelessWidget {
  const _BookmarksMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48, color: theme.colorScheme.outline),
                const SizedBox(height: 12),
                Text(message, style: theme.textTheme.bodyMedium),
                if (actionLabel != null) ...[
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

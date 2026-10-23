import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/gallery.dart';
import '../format.dart';
import '../gallery/gallery_page.dart';
import '../widgets/gallery_cover.dart';
import 'home_feed.dart';

/// Width / height of a gallery tile, shared by the carousel and the grid so
/// both read with the same cover proportions.
const _tileAspectRatio = 0.68;

/// Side margin of the home content, shared by the grid and the carousel.
const _homeMargin = 12.0;

/// Gap between grid columns, also used between popular cards.
const _gridGap = 8.0;

/// Popular cards are a little larger than a grid tile.
const _popularScale = 1.33;

/// Home tab: a "Popular Now" carousel above a "New Uploads" grid.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(homeFeedProvider);
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => ref.refresh(homeFeedProvider.future),
        child: switch (feed) {
          AsyncData(:final value) => _FeedView(feed: value),
          AsyncError() => _FeedMessage(
            icon: Icons.cloud_off,
            // Don't leak the Dio error into the UI; the cause is on screen
            // only for the developer.
            message: "Couldn't load the feed",
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(homeFeedProvider),
          ),
          _ => const _FeedLoading(),
        },
      ),
    );
  }
}

class _FeedView extends StatelessWidget {
  const _FeedView({required this.feed});

  final HomeFeed feed;

  @override
  Widget build(BuildContext context) {
    if (feed.popular.isEmpty && feed.newUploads.items.isEmpty) {
      return const _FeedMessage(
        icon: Icons.inbox_outlined,
        message: 'Nothing to show right now',
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (feed.popular.isNotEmpty) ...[
          const SliverToBoxAdapter(child: _SectionHeader(title: 'Popular Now')),
          SliverToBoxAdapter(child: _PopularCarousel(feed: feed)),
        ],
        if (feed.newUploads.items.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: _SectionHeader(title: 'New Uploads'),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: _homeMargin),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: _gridGap,
                mainAxisSpacing: _gridGap,
                childAspectRatio: _tileAspectRatio,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _GalleryTile(
                  gallery: feed.newUploads.items[i],
                  feed: feed,
                ),
                childCount: feed.newUploads.items.length,
              ),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _PopularCarousel extends StatelessWidget {
  const _PopularCarousel({required this.feed});

  final HomeFeed feed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use the same width the grid gives each tile, scaled up a little.
        final gridTileWidth =
            (constraints.maxWidth - _homeMargin * 2 - _gridGap * 2) / 3;
        final cardWidth = gridTileWidth * _popularScale;
        return SizedBox(
          height: cardWidth / _tileAspectRatio,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: _homeMargin),
            itemCount: feed.popular.length,
            separatorBuilder: (_, _) => const SizedBox(width: _gridGap),
            itemBuilder: (context, i) => SizedBox(
              width: cardWidth,
              child: _PopularCard(gallery: feed.popular[i], feed: feed),
            ),
          ),
        );
      },
    );
  }
}

class _PopularCard extends StatelessWidget {
  const _PopularCard({required this.gallery, required this.feed});

  final GalleryListItem gallery;
  final HomeFeed feed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          GalleryCover(url: feed.thumbnailUrl(gallery)),
          // Scrim keeps the overlaid title readable over any cover art.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.5, 1],
                colors: [Colors.transparent, Colors.black87],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  gallery.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.favorite,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formatCount(gallery.numFavorites),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: Semantics(
              button: true,
              label: 'Open ${gallery.displayTitle}',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => openGallery(context, gallery.id),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({required this.gallery, required this.feed});

  final GalleryListItem gallery;
  final HomeFeed feed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          GalleryCover(url: feed.thumbnailUrl(gallery)),
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
          Positioned.fill(
            child: Semantics(
              button: true,
              label: 'Open ${gallery.displayTitle}',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => openGallery(context, gallery.id),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FeedLoading extends StatelessWidget {
  const _FeedLoading();

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

class _FeedMessage extends StatelessWidget {
  const _FeedMessage({
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

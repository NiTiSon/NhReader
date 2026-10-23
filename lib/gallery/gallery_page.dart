import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/gallery.dart';
import '../bookmarks/bookmarks_feed.dart';
import '../format.dart';
import '../home/home_feed.dart';
import '../menu/account_selector.dart';
import '../settings/settings_providers.dart';
import '../widgets/gallery_cover.dart';
import 'gallery_provider.dart';

Future<void> openGallery(BuildContext context, int id) {
  return Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => GalleryPage(id: id)));
}

/// Full gallery details, opened from a cover tile.
class GalleryPage extends ConsumerWidget {
  const GalleryPage({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(galleryPageProvider(id));
    return switch (page) {
      AsyncData(:final value) => _GalleryView(
        key: ValueKey(value),
        data: value,
      ),
      AsyncError() => Scaffold(
        appBar: AppBar(),
        body: _GalleryMessage(
          message: "Couldn't load this title",
          onRetry: () => ref.invalidate(galleryPageProvider(id)),
        ),
      ),
      _ => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

enum _MenuAction { refresh, copyLink }

class _GalleryView extends ConsumerStatefulWidget {
  const _GalleryView({super.key, required this.data});

  final GalleryPageData data;

  @override
  ConsumerState<_GalleryView> createState() => _GalleryViewState();
}

class _GalleryViewState extends ConsumerState<_GalleryView> {
  int _tab = 0;
  late bool _favorited = widget.data.detail.isFavorited ?? false;
  late int _favoriteCount = widget.data.detail.numFavorites;
  bool _savingFavorite = false;

  Future<void> _toggleFavorite() async {
    if (_savingFavorite) return;
    final account = await ref.read(activeAccountProvider.future);
    if (!mounted) return;
    if (account == null) {
      await showAccountSelector(context);
      return;
    }

    final desired = !_favorited;
    final previousCount = _favoriteCount;
    setState(() {
      _savingFavorite = true;
      _favorited = desired;
      _favoriteCount += desired ? 1 : -1;
    });
    try {
      final result = await ref
          .read(nhentaiApiProvider)
          .setFavorite(widget.data.detail.id, desired);
      if (!mounted) return;
      setState(() {
        _savingFavorite = false;
        _favorited = result.favorited;
        _favoriteCount = result.numFavorites ?? _favoriteCount;
      });
      ref.invalidate(bookmarksProvider);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _savingFavorite = false;
        _favorited = !desired;
        _favoriteCount = previousCount;
      });
      _showMessage("Couldn't update favorite");
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _onMenuSelected(_MenuAction action) {
    switch (action) {
      case _MenuAction.refresh:
        ref.invalidate(galleryPageProvider(widget.data.detail.id));
        break;
      case _MenuAction.copyLink:
        final link = 'https://nhentai.net/g/${widget.data.detail.id}/';
        Clipboard.setData(ClipboardData(text: link));
        _showMessage('Link copied');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.data.detail;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        flexibleSpace: const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x99000000), Color(0x00000000)],
              ),
            ),
          ),
        ),
        actions: [
          PopupMenuButton<_MenuAction>(
            tooltip: 'More',
            icon: const Icon(Icons.more_horiz),
            onSelected: _onMenuSelected,
            itemBuilder: (_) => const [
              PopupMenuItem(value: _MenuAction.refresh, child: Text('Refresh')),
              PopupMenuItem(
                value: _MenuAction.copyLink,
                child: Text('Copy link'),
              ),
            ],
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _Header(
              data: widget.data,
              favorited: _favorited,
              favoriteCount: _favoriteCount,
              savingFavorite: _savingFavorite,
              onFavorite: _toggleFavorite,
              onRead: () => _showMessage('Reader coming soon'),
            ),
          ),
          SliverToBoxAdapter(
            child: _DetailsPanel(
              detail: detail,
              favoriteCount: _favoriteCount,
              tab: _tab,
              onTab: (tab) => setState(() => _tab = tab),
              onMoreTags: () => setState(() => _tab = 1),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.data,
    required this.favorited,
    required this.favoriteCount,
    required this.savingFavorite,
    required this.onFavorite,
    required this.onRead,
  });

  final GalleryPageData data;
  final bool favorited;
  final int favoriteCount;
  final bool savingFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = data.detail;
    final top = MediaQuery.paddingOf(context).top + kToolbarHeight + 16;
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(child: _Backdrop(url: data.coverUrl)),
        ),
        Column(
          children: [
            SizedBox(height: top),
            Center(
              child: _CoverCard(
                detail: detail,
                url: data.coverUrl,
                favoriteCount: favoriteCount,
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _TitleBlock(detail: detail),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: savingFavorite ? null : onFavorite,
                      icon: Icon(
                        favorited ? Icons.bookmark : Icons.bookmark_border,
                      ),
                      label: Text(favorited ? 'Favorited' : 'Favorite'),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.surfaceContainerHigh,
                        foregroundColor: theme.colorScheme.primary,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onRead,
                      icon: const Icon(Icons.menu_book),
                      label: const Text('Read'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ],
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: url.isEmpty
                ? const ColoredBox(color: Color(0xFF1A1218))
                : Transform.scale(
                    scale: 1.15,
                    child: GalleryCover(url: url, cacheKey: url),
                  ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.72, 1],
                colors: [
                  Colors.black.withValues(alpha: 0.42),
                  Colors.black.withValues(alpha: 0.55),
                  surface,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverCard extends StatelessWidget {
  const _CoverCard({
    required this.detail,
    required this.url,
    required this.favoriteCount,
  });

  final GalleryDetail detail;
  final String url;
  final int favoriteCount;

  @override
  Widget build(BuildContext context) {
    final cover = detail.cover;
    final aspectRatio = cover.width > 0 && cover.height > 0
        ? cover.width / cover.height
        : 0.68;
    final width = math.min(MediaQuery.sizeOf(context).width * 0.52, 220.0);
    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x73000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                GalleryCover(url: url),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 10,
                  child: Center(child: _FavoritePill(count: favoriteCount)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FavoritePill extends StatelessWidget {
  const _FavoritePill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$count favorites',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite, size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              formatCount(count),
              style: theme.textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.detail});

  final GalleryDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = detail.title.displayTitle;
    final secondary = detail.title.secondaryTitle;
    return Column(
      children: [
        Text(
          title.isEmpty ? 'Untitled' : title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (secondary != null) ...[
          const SizedBox(height: 6),
          Text(
            secondary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        ],
      ],
    );
  }
}

class _DetailsPanel extends StatelessWidget {
  const _DetailsPanel({
    required this.detail,
    required this.favoriteCount,
    required this.tab,
    required this.onTab,
    required this.onMoreTags,
  });

  final GalleryDetail detail;
  final int favoriteCount;
  final int tab;
  final ValueChanged<int> onTab;
  final VoidCallback onMoreTags;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        children: [
          _TabStrip(selected: tab, onTab: onTab),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            child: switch (tab) {
              0 => _AboutTab(
                detail: detail,
                favoriteCount: favoriteCount,
                onMoreTags: onMoreTags,
              ),
              1 => const _CommentsTab(),
              _ => _TagsTab(tags: detail.tags),
            },
          ),
          SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }
}

class _CommentsTab extends StatelessWidget {
  const _CommentsTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(
          Icons.comment_outlined,
          size: 32,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(height: 12),
        Text(
          'Comments coming soon.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.selected, required this.onTab});

  final int selected;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              label: 'About',
              selected: selected == 0,
              onTap: () => onTab(0),
            ),
          ),
          Expanded(
            child: _TabButton(
              label: 'Tags',
              selected: selected == 1,
              onTap: () => onTab(1),
            ),
          ),
          Expanded(
            child: _TabButton(
              label: 'Comments',
              selected: selected == 2,
              onTap: () => onTab(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: selected
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 3,
              width: 40,
              decoration: BoxDecoration(
                color: selected
                    ? theme.colorScheme.primary
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutTab extends StatelessWidget {
  const _AboutTab({
    required this.detail,
    required this.favoriteCount,
    required this.onMoreTags,
  });

  final GalleryDetail detail;
  final int favoriteCount;
  final VoidCallback onMoreTags;

  static const _creatorTypes = {'artist', 'group'};
  static const _metadataTypes = {'category', 'language', ..._creatorTypes};

  @override
  Widget build(BuildContext context) {
    final creators = detail.tags
        .where((tag) => _creatorTypes.contains(tag.type))
        .toList();
    final tags = detail.tags
        .where((tag) => !_metadataTypes.contains(tag.type))
        .toList();
    final hasCreator = creators.any((tag) => tag.name.isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Metadata(detail: detail, favoriteCount: favoriteCount),
        if (hasCreator) ...[
          const SizedBox(height: 20),
          _CreatorCard(creators: creators),
        ],
        if (detail.scanlator.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Scanlator: ${detail.scanlator}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 20),
          _TagPreview(tags: tags, onMore: onMoreTags),
        ],
      ],
    );
  }
}

class _Metadata extends StatelessWidget {
  const _Metadata({required this.detail, required this.favoriteCount});

  final GalleryDetail detail;
  final int favoriteCount;

  @override
  Widget build(BuildContext context) {
    final category = detail.tags.where((tag) => tag.type == 'category');
    final language = detail.tags.where(
      (tag) => tag.type == 'language' && tag.name.toLowerCase() != 'translated',
    );
    final year = detail.uploadDate > 0
        ? DateTime.fromMillisecondsSinceEpoch(detail.uploadDate * 1000).year
              .toString()
        : '—';
    final entries = [
      ('Category', category.isEmpty ? '—' : _titleCase(category.first.name)),
      ('Language', language.isEmpty ? '—' : _titleCase(language.first.name)),
      ('Pages', detail.numPages > 0 ? '${detail.numPages}' : '—'),
      ('Favorites', formatCount(favoriteCount)),
      ('Year', year),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 16.8;
        final columns = constraints.maxWidth < 480 || largeText ? 3 : 5;
        const gap = 8.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: 16,
          children: [
            for (final entry in entries)
              SizedBox(
                width: width,
                child: Column(
                  children: [
                    Text(
                      entry.$1,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entry.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CreatorCard extends StatelessWidget {
  const _CreatorCard({required this.creators});

  final List<GalleryTag> creators;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final artists = creators.where((tag) => tag.type == 'artist');
    final groups = creators.where((tag) => tag.type == 'group');
    final names = [
      ...artists,
      ...groups,
    ].map((tag) => tag.name).where((name) => name.isNotEmpty).join(' & ');
    final role = artists.isNotEmpty && groups.isNotEmpty
        ? 'Artist & Group'
        : groups.isNotEmpty
        ? 'Group'
        : 'Artist';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.person_outline,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  names,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  role,
                  style: theme.textTheme.bodySmall?.copyWith(
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

class _TagPreview extends StatelessWidget {
  const _TagPreview({required this.tags, required this.onMore});

  final List<GalleryTag> tags;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    const visibleCount = 10;
    final visible = tags.take(visibleCount).toList();
    final more = tags.length - visible.length;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tag in visible) _TagChip(label: tag.name, count: tag.count),
        if (more > 0) _TagChip(label: '+ $more more', onTap: onMore),
      ],
    );
  }
}

class _TagsTab extends StatelessWidget {
  const _TagsTab({required this.tags});

  final List<GalleryTag> tags;

  static const _order = [
    'category',
    'language',
    'parody',
    'character',
    'tag',
    'artist',
    'group',
  ];

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<GalleryTag>>{};
    for (final tag in tags) {
      groups.putIfAbsent(tag.type, () => []).add(tag);
    }
    final types = groups.keys.toList()
      ..sort((a, b) {
        final ai = _order.indexOf(a);
        final bi = _order.indexOf(b);
        if (ai == -1 && bi == -1) return a.compareTo(b);
        if (ai == -1) return 1;
        if (bi == -1) return -1;
        return ai.compareTo(bi);
      });

    if (types.isEmpty) {
      return Text(
        'No tags',
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < types.length; i++) ...[
          if (i > 0) const SizedBox(height: 20),
          Text(
            _groupLabel(types[i]).toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in groups[types[i]]!)
                _TagChip(label: tag.name, count: tag.count),
            ],
          ),
        ],
      ],
    );
  }

  static String _groupLabel(String type) {
    return switch (type) {
      'category' => 'Categories',
      'language' => 'Languages',
      'parody' => 'Parodies',
      'character' => 'Characters',
      'tag' => 'General',
      'artist' => 'Artists',
      'group' => 'Groups',
      _ => _titleCase(type),
    };
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, this.count, this.onTap});

  final String label;
  final int? count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface,
      fontWeight: FontWeight.w500,
    );
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              width: 1,
              height: 12,
              color: theme.colorScheme.outlineVariant,
            ),
            const SizedBox(width: 8),
            Text(
              formatCount(count!).toLowerCase(),
              style: style?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return chip;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: chip,
      ),
    );
  }
}

class _GalleryMessage extends StatelessWidget {
  const _GalleryMessage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(message),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

String _titleCase(String value) {
  if (value.isEmpty) return value;
  return value
      .split(' ')
      .map((word) {
        if (word.isEmpty) return word;
        return word[0].toUpperCase() + word.substring(1);
      })
      .join(' ');
}

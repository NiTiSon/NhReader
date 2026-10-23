/// Models for the gallery list endpoints.
///
/// Field names mirror `docs/nhentai.openapi.json` exactly.
class GalleryListItem {
  const GalleryListItem({
    required this.id,
    required this.mediaId,
    required this.englishTitle,
    required this.thumbnail,
    required this.thumbnailWidth,
    required this.thumbnailHeight,
    this.japaneseTitle,
    this.numFavorites = 0,
    this.numPages = 0,
    this.blacklisted = false,
  });

  factory GalleryListItem.fromJson(Map<String, dynamic> json) {
    return GalleryListItem(
      id: json['id'] as int,
      mediaId: json['media_id'] as String,
      englishTitle: json['english_title'] as String,
      // Relative CDN path, not a URL. Join it with a server from
      // GET /api/v2/cdn — never guess the host or extension.
      thumbnail: json['thumbnail'] as String,
      thumbnailWidth: json['thumbnail_width'] as int,
      thumbnailHeight: json['thumbnail_height'] as int,
      japaneseTitle: json['japanese_title'] as String?,
      numFavorites: json['num_favorites'] as int? ?? 0,
      numPages: json['num_pages'] as int? ?? 0,
      blacklisted: json['blacklisted'] as bool? ?? false,
    );
  }

  final int id;
  final String mediaId;
  final String englishTitle;
  final String? japaneseTitle;
  final String thumbnail;
  final int thumbnailWidth;
  final int thumbnailHeight;
  final int numFavorites;
  final int numPages;
  final bool blacklisted;

  /// Title to show in the UI, falling back to Japanese when English is absent.
  String get displayTitle => englishTitle.trim().isEmpty
      ? (japaneseTitle ?? englishTitle)
      : englishTitle;
}

/// Joins a CDN server with a relative media path. The API returns paths, not
/// URLs, and explicitly forbids guessing hosts.
String cdnUrl(List<String> servers, String path, int id) {
  if (servers.isEmpty || path.isEmpty) return '';
  final server = servers[id % servers.length];
  final normalized = path.startsWith('/') ? path : '/$path';
  return '$server$normalized';
}

/// Joins a CDN server with the item's relative thumbnail path.
String cdnThumbnailUrl(List<String> servers, GalleryListItem gallery) =>
    cdnUrl(servers, gallery.thumbnail, gallery.id);

class CoverInfo {
  const CoverInfo({
    required this.path,
    required this.width,
    required this.height,
  });

  factory CoverInfo.fromJson(Map<String, dynamic> json) {
    return CoverInfo(
      path: json['path'] as String,
      width: json['width'] as int,
      height: json['height'] as int,
    );
  }

  final String path;
  final int width;
  final int height;
}

class GalleryTitle {
  const GalleryTitle({
    required this.english,
    required this.pretty,
    this.japanese,
  });

  factory GalleryTitle.fromJson(Map<String, dynamic> json) {
    return GalleryTitle(
      english: json['english'] as String? ?? '',
      pretty: json['pretty'] as String? ?? '',
      japanese: json['japanese'] as String?,
    );
  }

  final String english;
  final String pretty;
  final String? japanese;

  String get displayTitle {
    if (english.trim().isNotEmpty) return english.trim();
    if (pretty.trim().isNotEmpty) return pretty.trim();
    return japanese?.trim() ?? '';
  }

  String? get secondaryTitle {
    final japaneseTitle = japanese?.trim();
    if (japaneseTitle == null ||
        japaneseTitle.isEmpty ||
        japaneseTitle == displayTitle) {
      return null;
    }
    return japaneseTitle;
  }
}

class GalleryTag {
  const GalleryTag({
    required this.id,
    required this.type,
    required this.name,
    required this.slug,
    this.count = 0,
  });

  factory GalleryTag.fromJson(Map<String, dynamic> json) {
    return GalleryTag(
      id: json['id'] as int,
      type: json['type'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String? ?? '',
      count: json['count'] as int? ?? 0,
    );
  }

  final int id;
  final String type;
  final String name;
  final String slug;
  final int count;
}

class GalleryDetail {
  const GalleryDetail({
    required this.id,
    required this.mediaId,
    required this.title,
    required this.cover,
    required this.uploadDate,
    required this.tags,
    required this.numPages,
    required this.numFavorites,
    this.scanlator = '',
    this.isFavorited,
  });

  factory GalleryDetail.fromJson(Map<String, dynamic> json) {
    return GalleryDetail(
      id: json['id'] as int,
      mediaId: json['media_id'] as String,
      title: GalleryTitle.fromJson(json['title'] as Map<String, dynamic>),
      cover: CoverInfo.fromJson(json['cover'] as Map<String, dynamic>),
      uploadDate: json['upload_date'] as int? ?? 0,
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((e) => GalleryTag.fromJson(e as Map<String, dynamic>))
          .toList(),
      numPages: json['num_pages'] as int? ?? 0,
      numFavorites: json['num_favorites'] as int? ?? 0,
      scanlator: json['scanlator'] as String? ?? '',
      isFavorited: json['is_favorited'] as bool?,
    );
  }

  final int id;
  final String mediaId;
  final GalleryTitle title;
  final CoverInfo cover;
  final int uploadDate;
  final List<GalleryTag> tags;
  final int numPages;
  final int numFavorites;
  final String scanlator;
  final bool? isFavorited;
}

class FavoriteResult {
  const FavoriteResult({required this.favorited, this.numFavorites});

  factory FavoriteResult.fromJson(Map<String, dynamic> json) {
    return FavoriteResult(
      favorited: json['favorited'] as bool,
      numFavorites: json['num_favorites'] as int?,
    );
  }

  final bool favorited;
  final int? numFavorites;
}

/// Envelope for `GET /api/v2/galleries`. Note the field is `result`, and
/// there is no `page` field — track the current page yourself.
class PaginatedGalleries {
  const PaginatedGalleries({
    required this.items,
    required this.numPages,
    this.perPage = 25,
    this.total,
  });

  factory PaginatedGalleries.fromJson(Map<String, dynamic> json) {
    return PaginatedGalleries(
      items: (json['result'] as List<dynamic>)
          .map((e) => GalleryListItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      numPages: json['num_pages'] as int,
      perPage: json['per_page'] as int? ?? 25,
      total: json['total'] as int?,
    );
  }

  final List<GalleryListItem> items;
  final int numPages;
  final int perPage;
  final int? total;
}

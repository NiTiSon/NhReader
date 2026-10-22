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

/// Joins a CDN server with the item's relative thumbnail path. The API
/// returns paths, not URLs, and explicitly forbids guessing hosts.
String cdnThumbnailUrl(List<String> servers, GalleryListItem gallery) {
  if (servers.isEmpty) return '';
  final server = servers[gallery.id % servers.length];
  final path = gallery.thumbnail.startsWith('/')
      ? gallery.thumbnail
      : '/${gallery.thumbnail}';
  return '$server$path';
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

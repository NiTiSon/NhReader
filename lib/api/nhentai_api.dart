import 'package:dio/dio.dart';

import 'gallery.dart';
import 'user.dart';

/// Thin typed wrapper over the nhentai REST API v2.
///
/// Public endpoints work without credentials; passing an API key upgrades
/// the request to `auth=key`, which raises the `/galleries` rate limit from
/// 15/min to 30/min and personalizes results.
class NhentaiApi {
  NhentaiApi({Future<String?> Function()? apiKeyProvider}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: 'https://nhentai.net',
        headers: {
          'User-Agent': 'NhReader/0.1.0 (https://github.com/NiTiSon/NhReader)',
        },
      ),
    );
    if (apiKeyProvider != null) {
      _dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            // Resolved per request, so changing the active account takes
            // effect without rebuilding the client (and without a double
            // fetch on launch).
            final key = await apiKeyProvider();
            if (key != null && key.isNotEmpty) {
              options.headers['Authorization'] = 'Key $key';
            }
            handler.next(options);
          },
        ),
      );
    }
  }

  late final Dio _dio;

  /// Today's popular galleries. Rate limit: 8/min per IP.
  Future<List<GalleryListItem>> popular() async {
    final response = await _dio.get<List<dynamic>>(
      '/api/v2/galleries/popular',
    );
    return (response.data ?? const <dynamic>[])
        .map((e) => GalleryListItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PaginatedGalleries> newUploads({int page = 1, int perPage = 25}) {
    return _dio
        .get<Map<String, dynamic>>(
          '/api/v2/galleries',
          queryParameters: {'page': page, 'per_page': perPage},
        )
        .then((r) => PaginatedGalleries.fromJson(r.data!));
  }

  /// Profile of the owner of the configured API key.
  Future<UserProfile> me() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v2/user');
    return UserProfile.fromJson(response.data!);
  }

  // TODO: create separate class for CDN servers
  Future<List<String>> thumbServers() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v2/cdn');
    final servers = response.data?['thumb_servers'];
    return (servers as List<dynamic>? ?? const <dynamic>[])
        .cast<String>()
        .where((s) => s.isNotEmpty)
        .toList();
  }
}

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'auth.dart';
import 'gallery.dart';
import 'network_trace.dart';
import 'user.dart';

/// Thin typed wrapper over the nhentai REST API v2.
///
/// Public endpoints work without credentials; passing an account upgrades the
/// request to `Authorization: Key <api-key>` or `User <access-token>`, which
/// raises the `/galleries` rate limit and personalizes results.
class NhentaiApi {
  NhentaiApi({
    Future<String?> Function()? authorizationProvider,
    Future<String?> Function()? refreshAuthorization,
  }) {
    final options = BaseOptions(
      baseUrl: 'https://nhentai.net',
      headers: {
        'User-Agent': 'NhReader/0.1.0 (https://github.com/NiTiSon/NhReader)',
      },
    );
    _dio = Dio(options);
    // Login and refresh must not go through the interceptor: refresh would
    // otherwise retry itself and login would send the old account's token.
    _authDio = Dio(options);
    if (kDebugMode) {
      // Added first so failed attempts are traced before the auth interceptor
      // retries them.
      final trace = NetworkTraceInterceptor();
      _dio.interceptors.add(trace);
      _authDio.interceptors.add(trace);
    }
    if (authorizationProvider != null) {
      _dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            // Resolved per request, so changing the active account takes
            // effect without rebuilding the client (and without a double
            // fetch on launch).
            final header = await authorizationProvider();
            if (header != null && header.isNotEmpty) {
              options.headers['Authorization'] = header;
            }
            handler.next(options);
          },
          onError: (error, handler) async {
            final canRefresh =
                refreshAuthorization != null &&
                error.response?.statusCode == 401 &&
                error.requestOptions.extra['retried'] != true;
            if (!canRefresh) {
              handler.next(error);
              return;
            }
            error.requestOptions.extra['retried'] = true;
            try {
              final header = await refreshAuthorization();
              if (header == null) {
                handler.next(error);
                return;
              }
              error.requestOptions.headers['Authorization'] = header;
              handler.resolve(await _dio.fetch(error.requestOptions));
            } catch (_) {
              handler.next(error);
            }
          },
        ),
      );
    }
  }

  late final Dio _dio;
  late final Dio _authDio;

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

  /// One gallery with the personalization needed by the title screen.
  Future<GalleryDetail> galleryDetail(int id) {
    return _dio
        .get<Map<String, dynamic>>(
          '/api/v2/galleries/$id',
          queryParameters: {'include': 'favorite'},
        )
        .then((r) => GalleryDetail.fromJson(r.data!));
  }

  /// Add or remove a gallery from the active account's favorites.
  Future<FavoriteResult> setFavorite(int id, bool favorited) async {
    final response = favorited
        ? await _dio.post<Map<String, dynamic>>(
            '/api/v2/galleries/$id/favorite',
          )
        : await _dio.delete<Map<String, dynamic>>(
            '/api/v2/galleries/$id/favorite',
          );
    return FavoriteResult.fromJson(response.data!);
  }

  /// The active account's favorite galleries. Requires credentials.
  Future<PaginatedGalleries> favorites({String? q, int page = 1}) {
    return _dio
        .get<Map<String, dynamic>>(
          '/api/v2/favorites',
          queryParameters: {
            'page': page,
            if (q != null && q.isNotEmpty) 'q': q,
          },
        )
        .then((r) => PaginatedGalleries.fromJson(r.data!));
  }

  /// Profile of the active account (API key or user token).
  Future<UserProfile> me() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v2/user');
    return UserProfile.fromJson(response.data!);
  }

  Future<PowChallenge> pow(String action) async {
    final response = await _authDio.get<Map<String, dynamic>>(
      '/api/v2/pow',
      queryParameters: {'action': action},
    );
    return PowChallenge.fromJson(response.data!);
  }

  Future<CaptchaConfig> captcha() async {
    final response = await _authDio.get<Map<String, dynamic>>(
      '/api/v2/captcha',
    );
    return CaptchaConfig.fromJson(response.data!);
  }

  Future<AuthSession> login({
    required String username,
    required String password,
    required String powChallenge,
    required String powNonce,
    required String captchaResponse,
  }) async {
    final response = await _authDio.post<Map<String, dynamic>>(
      '/api/v2/auth/login',
      data: {
        'username': username,
        'password': password,
        'pow_challenge': powChallenge,
        'pow_nonce': powNonce,
        'captcha_response': captchaResponse,
      },
    );
    return AuthSession.fromJson(response.data!);
  }

  /// Exchanges a refresh token. The server rotates both tokens.
  Future<AuthSession> refresh(String refreshToken) async {
    final response = await _authDio.post<Map<String, dynamic>>(
      '/api/v2/auth/refresh',
      data: {'refresh_token': refreshToken},
    );
    return AuthSession.fromJson(response.data!);
  }

  /// CDN hosts for thumbnails and covers.
  Future<List<String>> thumbServers() async =>
      _serverList(await _cdnConfig(), 'thumb_servers');

  Future<Map<String, dynamic>> _cdnConfig() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v2/cdn');
    return response.data ?? const <String, dynamic>{};
  }

  List<String> _serverList(Map<String, dynamic> json, String key) {
    return (json[key] as List<dynamic>? ?? const <dynamic>[])
        .cast<String>()
        .where((s) => s.isNotEmpty)
        .toList();
  }
}

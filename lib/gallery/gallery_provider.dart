import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/gallery.dart';
import '../home/home_feed.dart';

class GalleryPageData {
  const GalleryPageData({required this.detail, required this.coverUrl});

  final GalleryDetail detail;
  final String coverUrl;
}

final galleryPageProvider = FutureProvider.autoDispose
    .family<GalleryPageData, int>((ref, id) async {
      final api = ref.watch(nhentaiApiProvider);
      final detailFuture = api.galleryDetail(id);
      final serversFuture = ref.watch(galleryCoverServersProvider.future);
      final detail = await detailFuture;
      final servers = await serversFuture;
      return GalleryPageData(
        detail: detail,
        coverUrl: cdnUrl(servers, detail.cover.path, detail.id),
      );
    });
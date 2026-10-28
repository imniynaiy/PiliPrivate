import 'package:flutter/foundation.dart' show debugPrint;
import 'package:PiliPlus/http/fav.dart';
import 'package:PiliPlus/http/follow.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:PiliPlus/utils/local_favorites.dart';

abstract final class LocalFavoritesSync {
  static Future<void> sync() async {
    if (!Accounts.main.isLogin) return;
    try {
      final follows = await FollowHttp.followings(
        vmid: Accounts.main.mid,
        pn: 1,
        ps: 50,
      );
      if (follows case Success(:final response)) {
        for (final user in response.list ?? const []) {
          await LocalFavorites.add('users', {
            'id': user.mid,
            'title': user.uname ?? '用户 ${user.mid}',
            'cover': user.face,
          });
        }
      }
    } catch (_) {}

    try {
      final subscriptions = await UserHttp.userSubFolder(
        mid: Accounts.main.mid,
        pn: 1,
        ps: 50,
      );
      if (subscriptions case Success(:final response)) {
        for (final item in response.list ?? const []) {
          final type = item.type == 21 ? 'series' : 'folders';
          await LocalFavorites.add(type, {
            'id': item.id,
            'title': item.title,
            'subtitle': item.upper?.name,
            'cover': item.cover,
            'kind': 'subscription',
            'mediaCount': item.mediaCount,
          });
        }
      }
    } catch (_) {}

    // Mirror folders created by this account and all of their saved videos.
    try {
      var folderPage = 1;
      while (true) {
        final folders = await FavHttp.userfavFolder(
          pn: folderPage,
          ps: 50,
          mid: Accounts.main.mid,
        );
        final response = switch (folders) {
          Success(:final response) => response,
          _ => null,
        };
        if (response == null) {
          debugPrint('Local favorites folder sync failed: $folders');
          break;
        }
        final folderList = response.list ?? const [];
        for (final folder in folderList) {
          final folderId = folder.id;
          if (folderId == 0) continue;
          await LocalFavorites.add('folders', {
            'id': folderId,
            'title': folder.title,
            'subtitle': folder.upper?.name,
            'cover': folder.cover,
            'kind': 'favorite',
            'mediaCount': folder.mediaCount,
          });

          var videoPage = 1;
          while (true) {
            final detail = await FavHttp.userFavFolderDetail(
              mediaId: folderId,
              pn: videoPage,
              ps: 100,
            );
            final detailResponse = switch (detail) {
              Success(:final response) => response,
              _ => null,
            };
            if (detailResponse == null) {
              debugPrint(
                'Local favorite videos sync failed for folder $folderId',
              );
              break;
            }
            for (final media in detailResponse.medias ?? const []) {
              final bvid =
                  media.bvid ??
                  (media.type == 2 && media.id != null
                      ? IdUtils.av2bv(media.id!)
                      : null);
              if (bvid == null || bvid.isEmpty) continue;
              await LocalFavorites.add('videos', {
                'id': bvid,
                'cid': media.ugc?.firstCid ?? 0,
                'aid': media.id,
                'title': media.title,
                'subtitle': media.upper?.name,
                'cover': media.cover,
              });
            }
            if (detailResponse.hasMore != true ||
                detailResponse.medias?.isEmpty != false) {
              break;
            }
            videoPage++;
          }
        }
        if (response.hasMore != true || folderList.isEmpty) break;
        folderPage++;
      }
    } catch (error) {
      debugPrint('Local favorites online sync failed: $error');
    }
  }
}

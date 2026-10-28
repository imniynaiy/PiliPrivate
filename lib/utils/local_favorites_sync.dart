import 'package:PiliPlus/http/fav.dart';
import 'package:PiliPlus/http/follow.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/local_favorites.dart';

abstract final class LocalFavoritesSync {
  static Future<void> sync() async {
    if (!Accounts.main.isLogin) return;
    try {
      final follows = await FollowHttp.followings(vmid: Accounts.main.mid, pn: 1, ps: 50);
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
      final subscriptions = await UserHttp.userSubFolder(mid: Accounts.main.mid, pn: 1, ps: 50);
      if (subscriptions case Success(:final response)) {
        for (final item in response.list ?? const []) {
          final type = item.type == 21 ? 'series' : 'folders';
          await LocalFavorites.add(type, {
            'id': item.id,
            'title': item.title,
            'subtitle': item.upper?.name,
            'cover': item.cover,
            'kind': 'subscription',
          });
        }
      }
    } catch (_) {}

    // Pull a page of each online favorite folder; local-only entries remain intact.
    try {
      final folders = await FavHttp.userfavFolder(pn: 1, ps: 50, mid: Accounts.main.mid);
      if (folders case Success(:final response)) {
        for (final folder in response.list ?? const []) {
          final id = folder.id;
          if (id == 0) continue;
          final detail = await FavHttp.userFavFolderDetail(mediaId: id, pn: 1, ps: 100);
          if (detail case Success(:final response)) {
            for (final media in response.medias ?? const []) {
              if (media.bvid case final bvid? when bvid.isNotEmpty) {
                await LocalFavorites.add('videos', {
                  'id': bvid,
                  'cid': media.ugc?.firstCid,
                  'aid': media.id,
                  'title': media.title,
                  'subtitle': media.upper?.name,
                  'cover': media.cover,
                });
              }
            }
          }
        }
      }
    } catch (_) {}
  }
}

import 'package:PiliPlus/http/fav.dart';
import 'package:PiliPlus/http/follow.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/models/local_favorite.dart';
import 'package:PiliPlus/models_new/fav/fav_folder/list.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:PiliPlus/utils/local_favorites.dart';

class LocalSyncResult {
  final Map<String, int> counts = {};
  final List<String> errors = [];
  String get message => [
    if (counts.isNotEmpty)
      counts.entries
          .map(
            (e) =>
                '${const {'users': '关注', 'folders': '收藏夹', 'series': '合集', 'videos': '视频'}[e.key] ?? e.key}: ${e.value}',
          )
          .join('，'),
    if (errors.isNotEmpty) '同步未完成：${errors.join('；')}',
    if (counts.isEmpty && errors.isEmpty) '同步完成',
  ].join('\n');
}

abstract final class LocalFavoritesSync {
  static Future<LocalSyncResult>? _pending;
  static late LocalSyncResult _result;
  static late int _mid;
  static void _checkAccount() {
    if (!Accounts.main.isLogin || Accounts.main.mid != _mid) {
      throw StateError('账号已更改，请重新同步');
    }
  }

  static Future<LocalSyncResult> sync() =>
      _pending ??= _run().whenComplete(() => _pending = null);

  static Future<LocalSyncResult> _run() async {
    _result = LocalSyncResult();
    if (!Accounts.main.isLogin) {
      _result.errors.add('请先登录');
      return _result;
    }
    _mid = Accounts.main.mid;
    await _syncUsers();
    await _syncSubscriptions();
    await _syncFavorites();
    return _result;
  }

  static Future<void> _save(
    String type,
    Iterable<LocalFavorite> incoming,
  ) async {
    _checkAccount();
    final items = incoming.toList();
    await LocalFavorites.addAll(type, items);
    _result.counts[type] = (_result.counts[type] ?? 0) + items.length;
  }

  static Future<void> _syncUsers() async {
    try {
      var page = 1;
      while (true) {
        _checkAccount();
        final response = await FollowHttp.followings(
          vmid: _mid,
          pn: page,
          ps: 50,
        );
        if (response case Success(:final response)) {
          await _save(
            LocalFavorites.users,
            (response.list ?? const []).map(
              (user) => LocalFavorite(
                id: '${user.mid}',
                title: user.uname,
                cover: user.face,
                subtitle: user.sign,
              ),
            ),
          );
          if ((response.list?.length ?? 0) < 50 ||
              page * 50 >= (response.total ?? 1 << 30)) {
            break;
          }
          page++;
        } else {
          throw response;
        }
      }
    } catch (error) {
      _result.errors.add('关注: $error');
    }
  }

  static Future<void> _syncSubscriptions() async {
    try {
      var page = 1;
      while (true) {
        _checkAccount();
        final response = await UserHttp.userSubFolder(
          mid: _mid,
          pn: page,
          ps: 50,
        );
        if (response case Success(:final response)) {
          final folders = <LocalFavorite>[];
          final series = <LocalFavorite>[];
          for (final item in response.list ?? const []) {
            final target = item.type == 21 ? series : folders;
            if (item.id != null) {
              target.add(
                LocalFavorite(
                  id: '${item.type == 21 ? 'series' : 'subscription'}:${item.id}',
                  sourceMid: _mid,
                  sourceId: item.id,
                  title: item.title,
                  subtitle: item.upper?.name,
                  cover: item.cover,
                  kind: 'subscription',
                  mediaCount: item.mediaCount,
                ),
              );
            }
          }
          await _save(LocalFavorites.folders, folders);
          await _save(LocalFavorites.series, series);
          for (final item in response.list ?? const []) {
            if (item.id == null) continue;
            if (item.type == 21) {
              await _syncCollection(item.id!);
            } else {
              await _syncFolderVideos(
                FavFolderInfo(id: item.id!),
                key: 'subscription:${item.id}',
              );
            }
          }
          if (response.hasMore != true || response.list?.isEmpty != false) {
            break;
          }
          page++;
        } else {
          throw response;
        }
      }
    } catch (error) {
      _result.errors.add('订阅: $error');
    }
  }

  static Future<void> _syncFavorites() async {
    try {
      var page = 1;
      while (true) {
        _checkAccount();
        final folders = await FavHttp.userfavFolder(
          pn: page,
          ps: 20,
          mid: _mid,
        );
        if (folders is! Success) throw folders;
        final response = folders.data;
        final folderItems = response.list ?? const [];
        await _save(
          LocalFavorites.folders,
          folderItems.map(
            (folder) => LocalFavorite(
              id: 'favorite:${folder.id}',
              sourceMid: _mid,
              sourceId: folder.id,
              title: folder.title,
              subtitle: folder.upper?.name,
              cover: folder.cover,
              kind: 'favorite',
              mediaCount: folder.mediaCount,
            ),
          ),
        );
        for (final folder in folderItems) {
          await _syncFolderVideos(folder);
        }
        if (response.hasMore != true || folderItems.isEmpty) break;
        page++;
      }
    } catch (error) {
      _result.errors.add('收藏夹: $error');
    }
  }

  static Future<void> _syncFolderVideos(
    FavFolderInfo folder, {
    String? key,
  }) async {
    key ??= 'favorite:${folder.id}';
    final folderId = folder.id;
    if (folderId == 0) return;
    try {
      _checkAccount();
      await LocalFavorites.importContents(key, const [], complete: false);
      var page = 1;
      while (true) {
        _checkAccount();
        final details = await FavHttp.userFavFolderDetail(
          mediaId: folderId,
          pn: page,
          ps: 100,
        );
        if (details is! Success) throw details;
        final response = details.data;
        _checkAccount();
        await LocalFavorites.importContents(
          key,
          (response.medias ?? const [])
              .where((media) {
                return media.bvid?.isNotEmpty == true ||
                    media.id != null && media.type == 2;
              })
              .map(
                (media) => LocalFavorite(
                  id: media.bvid?.isNotEmpty == true
                      ? media.bvid!
                      : IdUtils.av2bv(media.id!),
                  title: media.title,
                  subtitle: media.upper?.name,
                  cover: media.cover,
                  cid: media.ugc?.firstCid,
                  aid: media.id,
                ),
              ),
          complete: response.hasMore != true,
        );
        _result.counts['videos'] =
            (_result.counts['videos'] ?? 0) + (response.medias?.length ?? 0);
        if (response.hasMore != true || response.medias?.isEmpty != false) {
          break;
        }
        page++;
      }
    } catch (error) {
      _result.errors.add('收藏夹 $folderId 视频: $error');
    }
  }

  static Future<void> _syncCollection(int id) async {
    try {
      _checkAccount();
      await LocalFavorites.importContents(
        'series:$id',
        const [],
        complete: false,
      );
      var page = 1;
      var received = 0;
      while (true) {
        _checkAccount();
        final result = await FavHttp.favSeasonList(id: id, pn: page, ps: 20);
        if (result is! Success) throw result;
        _checkAccount();
        final response = result.data;
        final medias = response.medias ?? const [];
        received += medias.length;
        final done =
            medias.isEmpty ||
            ((response.info?.mediaCount ?? 0) > 0 &&
                received >= response.info!.mediaCount!) ||
            medias.length < 20;
        await LocalFavorites.importContents(
          'series:$id',
          medias
              .where((e) => e.bvid?.isNotEmpty == true)
              .map(
                (e) => LocalFavorite(
                  id: e.bvid!,
                  aid: e.id,
                  title: e.title,
                  cover: e.cover,
                ),
              ),
          complete: done,
        );
        _result.counts['videos'] =
            (_result.counts['videos'] ?? 0) + medias.length;
        if (done) break;
        page++;
      }
    } catch (error) {
      _result.errors.add('合集 $id: $error');
    }
  }
}

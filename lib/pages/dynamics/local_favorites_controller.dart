import 'package:PiliPlus/pages/local_library/view.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/models/local_favorite.dart';
import 'package:PiliPlus/models/model_owner.dart';
import 'package:PiliPlus/models_new/fav/fav_detail/media.dart';
import 'package:PiliPlus/models_new/fav/fav_detail/ugc.dart';
import 'package:PiliPlus/models_new/fav/fav_folder/list.dart';
import 'package:PiliPlus/models_new/follow/list.dart';
import 'package:PiliPlus/utils/local_favorites.dart';
import 'package:PiliPlus/utils/local_favorites_sync.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:get/get.dart';

class LocalFavoritesController extends GetxController {
  final revision = LocalFavorites.revision;

  List<LocalFavorite> list(String type) => LocalFavorites.list(type);

  Future<LocalSyncResult> sync() => LocalFavoritesSync.sync();

  Future<void> remove(String type, LocalFavorite item) =>
      LocalFavorites.remove(type, item.id);

  FollowItemModel followItem(LocalFavorite item) => FollowItemModel(
    mid: int.tryParse(item.id) ?? 0,
    uname: item.title ?? '用户 ${item.id}',
    face: item.cover,
    sign: item.subtitle,
  );

  FavDetailItemModel videoItem(LocalFavorite item) => FavDetailItemModel(
    id: item.aid,
    type: 0,
    bvid: item.id,
    title: LocalFavorites.title(item),
    cover: item.cover,
    upper: Owner(name: item.subtitle),
    ugc: Ugc(firstCid: item.cid),
  );

  FavFolderInfo folderItem(LocalFavorite item) => FavFolderInfo(
    id: int.tryParse(item.id) ?? 0,
    title: LocalFavorites.title(item),
    cover: item.cover ?? '',
    intro: item.subtitle,
    mediaCount: LocalFavorites.contents(item.id).length,
  );

  String heroTag(String type, LocalFavorite item) =>
      Utils.makeHeroTag('local-$type-${item.id}');

  Future<void> openVideo(LocalFavorite item) async {
    final cid = item.cid != null && item.cid! > 0
        ? item.cid
        : (await SearchHttp.ab2cWithDimension(bvid: item.id))?.cid;
    if (cid == null) return;
    PageUtils.toVideoPage(
      bvid: item.id,
      aid: item.aid,
      cid: cid,
      cover: item.cover,
      title: item.title,
    );
  }

  void openFolder(String type, LocalFavorite item) {
    Get.to(() => LocalFolderPage(folder: item));
  }
}

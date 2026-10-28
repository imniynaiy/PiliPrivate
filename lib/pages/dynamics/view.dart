import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/models/model_owner.dart';
import 'package:PiliPlus/models_new/fav/fav_detail/media.dart';
import 'package:PiliPlus/models_new/fav/fav_detail/ugc.dart';
import 'package:PiliPlus/models_new/fav/fav_folder/list.dart';
import 'package:PiliPlus/models_new/follow/list.dart';
import 'package:PiliPlus/models_new/sub/sub/list.dart';
import 'package:PiliPlus/pages/common/common_page.dart';
import 'package:PiliPlus/pages/fav/video/widgets/item.dart';
import 'package:PiliPlus/pages/fav_detail/widget/fav_video_card.dart';
import 'package:PiliPlus/pages/follow/widgets/follow_item.dart';
import 'package:PiliPlus/utils/local_favorites.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

class DynamicsPage extends StatefulWidget {
  const DynamicsPage({super.key});

  @override
  State<DynamicsPage> createState() => _DynamicsPageState();
}

class _DynamicsPageState extends CommonPageState<DynamicsPage>
    with AutomaticKeepAliveClientMixin {
  static const _types = ['users', 'folders', 'series', 'videos'];
  static const _labels = ['关注', '收藏夹', '合集', '视频'];
  final _revision = 0.obs;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = Theme.of(context).colorScheme;
    return Localizations.override(
      context: context,
      locale: const Locale('zh', 'CN'),
      delegates: GlobalMaterialLocalizations.delegates,
      child: DefaultTabController(
        length: _types.length,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            primary: false,
            title: const Text('本地收藏'),
            bottom: TabBar(tabs: _labels.map((e) => Tab(text: e)).toList()),
            actions: [
              IconButton(
                tooltip: '刷新',
                onPressed: () => _revision.value++,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: TabBarView(
            children: List.generate(_types.length, (index) {
              final type = _types[index];
              return Obx(() {
                _revision.value;
                final items = LocalFavorites.list(type);
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      '暂无${_labels[index]}',
                      style: TextStyle(color: colors.outline),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, itemIndex) {
                    final item = items[itemIndex];
                    final id = item['id'];
                    return Row(
                      children: [
                        Expanded(child: _entry(type, item)),
                        PopupMenuButton<String>(
                          tooltip: '更多操作',
                          onSelected: (value) async {
                            if (value != 'remove') return;
                            final confirmed = await showConfirmDialog(
                              context: context,
                              title: const Text('确认删除'),
                              content: const Text('确定从本地收藏中移除此项目吗？'),
                            );
                            if (confirmed) {
                              await LocalFavorites.remove(type, id);
                              _revision.value++;
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'remove',
                              child: Text('移除本地收藏'),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                );
              });
            }),
          ),
        ),
      ),
    );
  }

  Widget _entry(String type, Map<String, dynamic> item) {
    final id = item['id'];
    if (type == 'users') {
      return FollowItem(
        item: FollowItemModel(
          mid: id as int,
          uname: '${item['title'] ?? item['name'] ?? '用户 $id'}',
          face: item['cover'] as String?,
          sign: item['subtitle'] as String?,
        ),
      );
    }

    if (type == 'videos') {
      final bvid = '$id';
      return FavVideoCardH(
        item: FavDetailItemModel(
          id: item['aid'] as int?,
          type: 0,
          bvid: bvid,
          title: '${item['title'] ?? bvid}',
          cover: item['cover'] as String?,
          upper: Owner(name: item['subtitle'] as String?),
          ugc: Ugc(firstCid: item['cid'] as int?),
        ),
        onTap: () {
          final cid = item['cid'] as int?;
          if (cid != null && cid > 0) {
            PageUtils.toVideoPage(
              bvid: bvid,
              aid: item['aid'] as int?,
              cid: cid,
              cover: item['cover'] as String?,
              title: item['title'] as String?,
            );
          }
        },
      );
    }

    final isSeries = type == 'series';
    final folder = FavFolderInfo(
      id: id as int,
      title: '${item['title'] ?? id}',
      cover: item['cover'] as String? ?? '',
      intro: item['subtitle'] as String?,
      mediaCount: item['mediaCount'] as int? ?? 0,
    );
    final heroTag = Utils.makeHeroTag('local-$type-$id');
    return FavVideoItem(
      heroTag: heroTag,
      item: folder,
      onTap: () {
        if (type == 'folders' && item['kind'] == 'favorite') {
          Get.toNamed(
            '/favDetail',
            parameters: {
              'mediaId': '$id',
              'heroTag': heroTag,
            },
          );
        } else {
          Get.toNamed(
            '/subDetail',
            arguments: {
              'id': id,
              'subInfo': SubItemModel(
                id: id,
                title: folder.title,
                cover: folder.cover,
                type: isSeries ? 21 : 11,
              ),
            },
          );
        }
      },
    );
  }
}

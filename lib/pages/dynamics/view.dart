import 'package:PiliPlus/pages/local_library/view.dart';
import 'package:PiliPlus/models/local_favorite.dart';
import 'package:PiliPlus/pages/dynamics/local_favorites_controller.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/pages/common/common_page.dart';
import 'package:PiliPlus/pages/fav/video/widgets/item.dart';
import 'package:PiliPlus/pages/follow/widgets/follow_item.dart';
import 'package:PiliPlus/utils/local_favorites.dart';
import 'package:PiliPlus/utils/local_favorites_sync.dart';
import 'package:material_ui/material_ui.dart';
import 'package:get/get.dart';

class DynamicsPage extends StatefulWidget {
  const DynamicsPage({super.key});

  @override
  State<DynamicsPage> createState() => _DynamicsPageState();
}

class _DynamicsPageState extends CommonPageState<DynamicsPage>
    with AutomaticKeepAliveClientMixin, GridMixin {
  final _controller = LocalFavoritesController();
  bool _syncing = false;
  static const _types = ['users', 'folders', 'series'];
  static const _labels = ['关注', '收藏夹', '合集'];
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
          primary: false,
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            primary: false,
            titleSpacing: 20,
            title: const Text('本地收藏'),
            bottom: TabBar(
              tabs: _labels.map((e) => Tab(text: e)).toList(),
            ),
            actions: [
              IconButton(
                tooltip: '新建收藏夹',
                icon: const Icon(Icons.create_new_folder_outlined),
                onPressed: () async {
                  final name = await localFolderName(context);
                  if (name != null) await LocalFavorites.createFolder(name);
                },
              ),
              IconButton(
                tooltip: '刷新',
                onPressed: _syncing ? null : _sync,
                icon: _syncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
          body: TabBarView(
            children: List.generate(_types.length, (index) {
              final type = _types[index];
              return Obx(() {
                LocalFavorites.revision.value;
                final items = LocalFavorites.list(type);
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      '暂无${_labels[index]}',
                      style: TextStyle(color: colors.outline),
                    ),
                  );
                }
                return refreshIndicator(
                  onRefresh: _sync,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        sliver: SliverGrid.builder(
                          gridDelegate: gridDelegate,
                          itemCount: items.length,
                          itemBuilder: (context, itemIndex) {
                            final item = items[itemIndex];
                            final id = item.id;
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                _entry(type, item),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: PopupMenuButton<String>(
                                    tooltip: '更多操作',
                                    onSelected: (value) async {
                                      if (value == 'rename') {
                                        final name = await localFolderName(
                                          context,
                                          initial: LocalFavorites.title(item),
                                        );
                                        if (name != null) {
                                          await LocalFavorites.renameFolder(
                                            item,
                                            name,
                                          );
                                        }
                                        return;
                                      }
                                      if (value != 'remove') return;
                                      final confirmed = await showConfirmDialog(
                                        context: context,
                                        title: const Text('确认删除'),
                                        content: const Text(
                                          '仅移除本地副本；失去所有归属的视频会移入默认收藏夹。',
                                        ),
                                      );
                                      if (confirmed) {
                                        await LocalFavorites.remove(type, id);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      if (type != LocalFavorites.users)
                                        const PopupMenuItem(
                                          value: 'rename',
                                          child: Text('重命名'),
                                        ),
                                      if (item.id !=
                                          LocalFavorites.defaultFolder)
                                        const PopupMenuItem(
                                          value: 'remove',
                                          child: Text('移除本地收藏'),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              });
            }),
          ),
        ),
      ),
    );
  }

  Future<void> _sync() async {
    if (_syncing) return;
    final confirmed = await showConfirmDialog(
      context: context,
      title: const Text('同步到本地收藏'),
      content: const Text('将当前账号的关注、收藏夹、合集及其视频列表复制到本地，保留已有内容，不下载视频文件。是否继续？'),
    );
    if (!confirmed || !mounted) return;
    setState(() => _syncing = true);
    try {
      final result = await LocalFavoritesSync.sync();
      SmartDialog.showToast(result.message);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Widget _entry(String type, LocalFavorite item) {
    if (type == LocalFavorites.users) {
      return FollowItem(item: _controller.followItem(item));
    }
    return FavVideoItem(
      heroTag: _controller.heroTag(type, item),
      item: _controller.folderItem(item),
      onTap: () => _controller.openFolder(type, item),
    );
  }
}

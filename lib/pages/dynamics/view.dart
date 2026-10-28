import 'package:PiliPlus/pages/common/common_page.dart';
import 'package:PiliPlus/utils/local_favorites.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/models_new/sub/sub/list.dart';
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
                return Center(child: Text('暂无${_labels[index]}', style: TextStyle(color: colors.outline)));
              }
              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final item = items[i];
                  final id = item['id'];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: item['cover'] is String && (item['cover'] as String).isNotEmpty
                          ? NetworkImage(item['cover'] as String)
                          : null,
                      child: item['cover'] == null ? const Icon(Icons.bookmark_outline) : null,
                    ),
                    title: Text('${item['title'] ?? item['name'] ?? id}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: item['subtitle'] == null ? null : Text('${item['subtitle']}', maxLines: 1),
                    onTap: () {
                      if (type == 'users') Get.toNamed('/member', parameters: {'mid': '$id'});
                      if (type == 'videos') {
                        final cid = item['cid'] as int?;
                        if (cid != null && cid > 0) {
                          PageUtils.toVideoPage(
                            bvid: '$id',
                            cid: cid,
                            aid: item['aid'] as int?,
                            cover: item['cover'] as String?,
                            title: item['title'] as String?,
                          );
                        }
                      }
                      if (type == 'folders') {
                        if (item['kind'] == 'favorite') {
                          Get.toNamed('/favDetail', parameters: {
                            'mediaId': '$id',
                            'heroTag': 'local-$id',
                          });
                        } else {
                          Get.toNamed('/subDetail', arguments: {
                            'id': id,
                            'subInfo': SubItemModel(
                              id: id as int?,
                              title: item['title'] as String?,
                              cover: item['cover'] as String?,
                              type: 11,
                            ),
                          });
                        }
                      }
                      if (type == 'series') {
                        Get.toNamed('/subDetail', arguments: {
                          'id': id,
                          'subInfo': SubItemModel(
                            id: id as int?,
                            title: item['title'] as String?,
                            cover: item['cover'] as String?,
                            type: 21,
                          ),
                        });
                      }
                    },
                    trailing: IconButton(
                      tooltip: '移除',
                      icon: const Icon(Icons.close),
                      onPressed: () async {
                        await LocalFavorites.remove(type, id);
                        _revision.value++;
                      },
                    ),
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
}

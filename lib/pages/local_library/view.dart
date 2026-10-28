import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/models/local_favorite.dart';
import 'package:PiliPlus/pages/dynamics/local_favorites_controller.dart';
import 'package:PiliPlus/pages/fav_detail/widget/fav_video_card.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/utils/local_favorites.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

Future<String?> localFolderName(BuildContext context, {String? initial}) async {
  var enteredName = initial ?? '';
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(initial == null ? '新建收藏夹' : '重命名收藏夹'),
      content: TextFormField(
        initialValue: initial,
        onChanged: (value) => enteredName = value,
        autofocus: true,
        decoration: const InputDecoration(labelText: '名称'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            final name = enteredName.trim();
            if (name.isNotEmpty) Navigator.pop(context, name);
          },
          child: const Text('确定'),
        ),
      ],
    ),
  );
  return result;
}

Future<bool> pickLocalFolders(BuildContext context, LocalFavorite video) async {
  final selected = LocalFavorites.memberships(video.id);
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .7,
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(width: 20),
                const Expanded(child: Text('保存到本地收藏夹')),
                TextButton.icon(
                  onPressed: () async {
                    final name = await localFolderName(context);
                    if (name == null) return;
                    final folder = await LocalFavorites.createFolder(name);
                    setState(() => selected.add(folder.id));
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('新建收藏夹'),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final folder in LocalFavorites.list(
                    LocalFavorites.folders,
                  ))
                    CheckboxListTile(
                      title: Text(LocalFavorites.title(folder)),
                      subtitle: Text(
                        '${LocalFavorites.contents(folder.id).length} 个视频',
                      ),
                      value: selected.contains(folder.id),
                      onChanged: (value) => setState(() {
                        if (value == true) {
                          selected.add(folder.id);
                        } else {
                          selected.remove(folder.id);
                        }
                      }),
                    ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                    FilledButton.tonal(
                      onPressed: () async {
                        await LocalFavorites.setMemberships(video, selected);
                        if (context.mounted) Navigator.pop(context, true);
                      },
                      child: const Text('完成'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return result == true;
}

class LocalFolderPage extends StatelessWidget {
  const LocalFolderPage({super.key, required this.folder});
  final LocalFavorite folder;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(LocalFavorites.title(folder))),
    body: Obx(() {
      LocalFavorites.revision.value;
      final videos = LocalFavorites.contents(folder.id);
      return CustomScrollView(
        slivers: [
          if (folder.kind != 'local' && !LocalFavorites.complete(folder.id))
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('内容尚未完整同步，请登录后在收藏页同步。'),
              ),
            ),
          if (videos.isEmpty)
            const SliverFillRemaining(child: Center(child: Text('暂无视频')))
          else
            SliverPadding(
              padding: EdgeInsets.only(
                top: 7,
                bottom: MediaQuery.viewPaddingOf(context).bottom + 12,
              ),
              sliver: SliverGrid.builder(
                gridDelegate: Grid.videoCardHDelegate(),
                itemCount: videos.length,
                itemBuilder: (context, index) {
                  final video = videos[index];
                  final controller = LocalFavoritesController();
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      FavVideoCardH(
                        item: controller.videoItem(video),
                        onTap: () => controller.openVideo(video),
                      ),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: PopupMenuButton<String>(
                          onSelected: (_) async {
                            if (await showConfirmDialog(
                              context: context,
                              title: const Text('移除视频'),
                              content: const Text('从当前本地收藏夹移除？'),
                            )) {
                              await LocalFavorites.removeMembership(
                                folder.id,
                                video.id,
                              );
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'remove',
                              child: Text('从此收藏夹移除'),
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
      );
    }),
  );
}

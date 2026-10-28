import 'package:PiliPlus/models/local_favorite.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';
import 'package:collection/collection.dart';

/// Device-local lists displayed by the 收藏 page.
abstract final class LocalFavorites {
  static const users = 'users';
  static const folders = 'folders';
  static const series = 'series';
  static const videos = 'videos';

  static const defaultFolder = 'local:default';
  static late Box<dynamic> box;
  static Future<void> init() async {
    box = await Hive.openBox<dynamic>('localLibrary');
    if (!box.containsKey(_key)) {
      final legacy = GStorage.localCache.get(_key, defaultValue: {});
      final migrated = Map<String, dynamic>.from(legacy as Map);
      for (final type in [folders, series]) {
        migrated[type] = [
          for (final raw in (migrated[type] as List? ?? const []))
            {
              ...Map<String, dynamic>.from(raw as Map),
              'id':
                  '${type == series ? 'series' : (raw['kind'] == 'subscription' ? 'subscription' : 'favorite')}:${raw['id']}',
            },
        ];
      }
      final members = <String, dynamic>{
        defaultFolder: [
          for (final raw in (migrated[videos] as List? ?? const []))
            '${(raw as Map)['id']}',
        ],
      };
      await box.putAll({_key: migrated, 'members': members});
    }
    if (!contains(folders, defaultFolder)) {
      await add(
        folders,
        const LocalFavorite(id: defaultFolder, title: '默认收藏夹', kind: 'local'),
      );
    }
  }

  static Map<String, dynamic> get _members =>
      Map<String, dynamic>.from(box.get('members', defaultValue: {}) as Map);
  static List<LocalFavorite> contents(String id) {
    final ids = List<String>.from(_members[id] ?? const []);
    final items = {for (final item in list(videos)) item.id: item};
    return [
      for (final id in ids)
        if (items[id] != null) items[id]!,
    ];
  }

  static Set<String> memberships(String videoId) => {
    for (final entry in _members.entries)
      if ((entry.value as List).contains(videoId)) entry.key,
  };
  static bool isVideoSaved(String id) =>
      list(folders).any((folder) => memberships(id).contains(folder.id));

  static Future<void> setMemberships(
    LocalFavorite video,
    Set<String> selected,
  ) async {
    await add(videos, video);
    final members = _members;
    for (final folder in list(folders)) {
      final ids = List<String>.from(members[folder.id] ?? const [])
        ..remove(video.id);
      if (selected.contains(folder.id)) ids.add(video.id);
      members[folder.id] = ids;
    }
    await box.put('members', members);
    revision.value++;
  }

  static Future<void> importContents(
    String id,
    Iterable<LocalFavorite> incoming, {
    bool complete = false,
  }) async {
    final items = incoming.toList();
    await addAll(videos, items);
    final members = _members;
    members[id] = {
      ...List<String>.from(members[id] ?? const []),
      ...items.map((e) => e.id),
    }.toList();
    await box.put('members', members);
    final state = Map<String, dynamic>.from(
      box.get('syncState', defaultValue: {}) as Map,
    );
    state[id] = {
      ...Map<String, dynamic>.from(state[id] as Map? ?? const {}),
      'complete': complete,
      if (complete) 'lastSync': DateTime.now().toIso8601String(),
    };
    await box.put('syncState', state);
    revision.value++;
  }

  static bool complete(String id) =>
      ((box.get('syncState', defaultValue: {}) as Map)[id]
          as Map?)?['complete'] ==
      true;
  static Future<void> removeMembership(String folder, String video) async {
    final members = _members;
    members[folder] = List<String>.from(members[folder] ?? const [])
      ..remove(video);
    await box.put('members', members);
    revision.value++;
  }

  static Future<LocalFavorite> createFolder(String title) async {
    final item = LocalFavorite(
      id: 'local:${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      kind: 'local',
    );
    await add(folders, item);
    return item;
  }

  static Future<void> renameFolder(LocalFavorite folder, String title) async {
    final names = Map<String, dynamic>.from(
      box.get('names', defaultValue: {}) as Map,
    );
    names[folder.id] = title;
    await box.put('names', names);
    revision.value++;
  }

  static String title(LocalFavorite folder) =>
      (box.get('names', defaultValue: {}) as Map)[folder.id] as String? ??
      folder.title ??
      folder.id;

  static const _key = 'localFavorites';
  static final RxInt revision = 0.obs;

  static Map<String, dynamic> get _data => Map<String, dynamic>.from(
    box.get(_key, defaultValue: {}) as Map,
  );

  static List<LocalFavorite> list(String type) => List<dynamic>.from(
    _data[type] ?? const [],
  ).map((item) => LocalFavorite.fromMap(item as Map)).toList();

  static bool contains(String type, Object id) => list(type).any(
    (item) =>
        item.id == '$id' ||
        ((type == folders || type == series) &&
            !'$id'.contains(':') &&
            item.id.endsWith(':$id')),
  );

  static Future<void> add(String type, LocalFavorite item) =>
      addAll(type, [item]);

  static Future<void> addAll(
    String type,
    Iterable<LocalFavorite> incoming,
  ) async {
    final data = _data;
    final items = list(type);
    for (var item in incoming) {
      if ((type == folders || type == series) && !item.id.contains(':')) {
        item = LocalFavorite.fromMap({
          ...item.toMap(),
          'id':
              '${type == series
                  ? 'series'
                  : item.kind == 'subscription'
                  ? 'subscription'
                  : 'favorite'}:${item.id}',
          'sourceId': int.tryParse(item.id),
        });
      }
      if (item.id.isEmpty) continue;
      final index = items.indexWhere((saved) => saved.id == item.id);
      if (index < 0) {
        items.insert(0, item);
      } else {
        items[index] = items[index].merge(item);
      }
    }
    data[type] = items.map((item) => item.toMap()).toList();
    await box.put(_key, data);
    revision.value++;
  }

  static Future<void> remove(String type, Object id) async {
    if ((type == folders || type == series) && !'$id'.contains(':')) {
      final match = list(type).firstWhereOrNull((e) => e.id.endsWith(':$id'));
      if (match != null) id = match.id;
    }
    if (id == defaultFolder) return;
    if (type == folders || type == series) {
      final members = _members;
      final removed = List<String>.from(members.remove('$id') ?? const []);
      final remaining = members.values
          .expand((e) => List<String>.from(e as List))
          .toSet();
      members[defaultFolder] = {
        ...List<String>.from(members[defaultFolder] ?? const []),
        ...removed.where((e) => !remaining.contains(e)),
      }.toList();
      await box.put('members', members);
    }
    final data = _data;
    data[type] = list(type)
        .where((item) => item.id != '$id')
        .map((item) => item.toMap())
        .toList();
    await box.put(_key, data);
    revision.value++;
  }
}

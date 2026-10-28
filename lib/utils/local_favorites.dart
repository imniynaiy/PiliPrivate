import 'package:PiliPlus/utils/storage.dart';
import 'package:get/get.dart';

/// Device-local metadata for items shown on the Dynamic page.
abstract final class LocalFavorites {
  static const _key = 'localFavorites';
  static final RxInt revision = 0.obs;
  static Map<String, dynamic> get _data => Map<String, dynamic>.from(
    GStorage.localCache.get(_key, defaultValue: {}) as Map,
  );

  static List<Map<String, dynamic>> list(String type) =>
      (List.from(_data[type] ?? const []))
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  static bool contains(String type, Object id) =>
      list(type).any((item) => '${item['id']}' == '$id');

  static void refresh() => revision.value++;

  static Future<void> add(String type, Map<String, dynamic> item) async {
    final data = _data;
    final items = List<Map<String, dynamic>>.from(
      (data[type] ?? const []).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    final id = '${item['id']}';
    final index = items.indexWhere((e) => '${e['id']}' == id);
    if (index < 0) {
      items.insert(0, item);
    } else {
      items[index] = {...items[index], ...item};
    }
    data[type] = items;
    await GStorage.localCache.put(_key, data);
    refresh();
  }

  static Future<void> remove(String type, Object id) async {
    final data = _data;
    final items = List.from(data[type] ?? const [])
      ..removeWhere((e) => '${(e as Map)['id']}' == '$id');
    data[type] = items;
    await GStorage.localCache.put(_key, data);
    refresh();
  }

  static Future<void> toggle(String type, Map<String, dynamic> item) async {
    final exists = list(type).any((e) => '${e['id']}' == '${item['id']}');
    if (exists) {
      await remove(type, item['id'] as Object);
    } else {
      await add(type, item);
    }
  }
}

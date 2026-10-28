import 'dart:io';

import 'package:PiliPlus/models/local_favorite.dart';
import 'package:PiliPlus/utils/local_favorites.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory directory;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('local_library_test');
    Hive.init(directory.path);
    GStorage.localCache = await Hive.openBox<dynamic>('localCache');
    await LocalFavorites.init();
  });
  setUp(() async {
    await GStorage.localCache.clear();
    await LocalFavorites.box.clear();
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'migration preserves flat videos and initialization is repeatable',
    () async {
      await GStorage.localCache.put('localFavorites', {
        'videos': [
          {'id': 'BVlegacy', 'title': 'Saved'},
        ],
        'folders': [
          {'id': 123, 'title': 'Old folder', 'kind': 'favorite'},
        ],
      });
      await LocalFavorites.init();
      await LocalFavorites.init();
      expect(
        LocalFavorites.contents(LocalFavorites.defaultFolder).single.id,
        'BVlegacy',
      );
      expect(LocalFavorites.list(LocalFavorites.folders), hasLength(2));
      expect(
        LocalFavorites.contains(LocalFavorites.folders, 'favorite:123'),
        isTrue,
      );
      expect(LocalFavorites.complete('favorite:123'), isFalse);
      await GStorage.localCache.clear();
      await LocalFavorites.box.close();
      await LocalFavorites.init();
      expect(
        LocalFavorites.contents(LocalFavorites.defaultFolder).single.id,
        'BVlegacy',
      );
    },
  );

  test(
    'multiple memberships, additive imports, rename and orphan preservation',
    () async {
      await LocalFavorites.init();
      final a = await LocalFavorites.createFolder('A');
      final b = await LocalFavorites.createFolder('B');
      const video = LocalFavorite(id: 'BVvideo', title: 'Saved title', cid: 12);
      await LocalFavorites.setMemberships(video, {a.id, b.id});
      await LocalFavorites.importContents(a.id, [
        const LocalFavorite(id: 'BVvideo', title: ''),
      ], complete: true);
      await LocalFavorites.importContents(a.id, [], complete: true);
      expect(LocalFavorites.contents(a.id).single.title, 'Saved title');
      expect(LocalFavorites.memberships(video.id), {a.id, b.id});
      await LocalFavorites.renameFolder(a, 'Renamed');
      await LocalFavorites.add(LocalFavorites.folders, a);
      expect(LocalFavorites.title(a), 'Renamed');
      await LocalFavorites.remove(LocalFavorites.folders, a.id);
      expect(LocalFavorites.memberships(video.id), {b.id});
      await LocalFavorites.remove(LocalFavorites.folders, b.id);
      expect(LocalFavorites.memberships(video.id), {
        LocalFavorites.defaultFolder,
      });
      await LocalFavorites.remove(
        LocalFavorites.folders,
        LocalFavorites.defaultFolder,
      );
      expect(
        LocalFavorites.contains(
          LocalFavorites.folders,
          LocalFavorites.defaultFolder,
        ),
        isTrue,
      );
    },
  );

  test(
    'collection memberships survive folder picker changes and partial imports',
    () async {
      await LocalFavorites.init();
      const video = LocalFavorite(id: 'BVvideo');
      await LocalFavorites.importContents('series:1', [video], complete: true);
      expect(LocalFavorites.isVideoSaved(video.id), isFalse);
      await LocalFavorites.setMemberships(video, {
        LocalFavorites.defaultFolder,
      });
      await LocalFavorites.importContents('series:1', [], complete: false);
      expect(LocalFavorites.contents('series:1').single.id, video.id);
      expect(LocalFavorites.complete('series:1'), isFalse);
      await LocalFavorites.removeMembership(
        LocalFavorites.defaultFolder,
        video.id,
      );
      expect(LocalFavorites.memberships(video.id), {'series:1'});
    },
  );
}

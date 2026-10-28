class LocalFavorite {
  const LocalFavorite({
    required this.id,
    this.title,
    this.subtitle,
    this.cover,
    this.cid,
    this.aid,
    this.mediaCount,
    this.kind,
    this.sourceMid,
    this.sourceId,
  });

  final String id;
  final String? title;
  final String? subtitle;
  final String? cover;
  final int? cid;
  final int? aid;
  final int? mediaCount;
  final String? kind;
  final int? sourceMid;
  final int? sourceId;

  factory LocalFavorite.fromMap(Map<dynamic, dynamic> map) => LocalFavorite(
    id: '${map['id'] ?? ''}',
    title: (map['title'] ?? map['name']) as String?,
    subtitle: map['subtitle'] as String?,
    cover: map['cover'] as String?,
    cid: (map['cid'] as num?)?.toInt(),
    aid: (map['aid'] as num?)?.toInt(),
    mediaCount: (map['mediaCount'] as num?)?.toInt(),
    kind: map['kind'] as String?,
    sourceMid: map['sourceMid'] as int?,
    sourceId: map['sourceId'] as int?,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': ?title,
    'subtitle': ?subtitle,
    'cover': ?cover,
    'cid': ?cid,
    'aid': ?aid,
    'mediaCount': ?mediaCount,
    'kind': ?kind,
    'sourceMid': ?sourceMid,
    'sourceId': ?sourceId,
  };

  LocalFavorite merge(LocalFavorite newer) => LocalFavorite(
    id: id,
    title: newer.title?.isNotEmpty == true ? newer.title : title,
    subtitle: newer.subtitle?.isNotEmpty == true ? newer.subtitle : subtitle,
    cover: newer.cover?.isNotEmpty == true ? newer.cover : cover,
    cid: newer.cid ?? cid,
    aid: newer.aid ?? aid,
    mediaCount: newer.mediaCount ?? mediaCount,
    kind: newer.kind ?? kind,
    sourceMid: newer.sourceMid ?? sourceMid,
    sourceId: newer.sourceId ?? sourceId,
  );
}

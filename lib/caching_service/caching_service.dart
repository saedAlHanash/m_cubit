import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';

import '../abstraction.dart';
import '../util.dart';

final Logger _logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 0,
    lineLength: 300,
    colors: true,
    printEmojis: false,
  ),
);

String get latestUpdateBox => '${mSupperFilter ?? ''}-latestUpdateBox';
const String _defaultBoxName = 'defaultBox';
const String _versionKey = '__v';

int _version = 1;
int time = 60;

String? mSupperFilter;
void Function(dynamic state)? onErrorFun;

class CachingService {
  //region Bucket
  static Future<void> initialOpenBucket(String bucket) async {
    try {
      await getBox(bucket);
    } catch (_) {}
  }

  static Future<void> addInBucket({
    required String key,
    required String jsonEncode,
    String? bucket,
  }) async {
    final box = await getBox(bucket ?? _defaultBoxName);
    await box.put(key, jsonEncode);
  }

  static void addInBucketSync({
    required String key,
    required String jsonEncode,
    String? bucket,
  }) {
    final box = getBoxSync(bucket ?? _defaultBoxName);
    box.put(key, jsonEncode);
  }

  static Future<String?> getFromBucket({
    String? bucket,
    required String key,
  }) async {
    final box = await getBox(bucket ?? _defaultBoxName);
    return box.get(key);
  }

  static Future<List<String>> getAllFromBucket({String? bucket}) async {
    final box = await getBox(bucket ?? _defaultBoxName);
    return box.values.toList();
  }

  static String? getFromBucketSync({
    String? bucket,
    required String key,
  }) {
    final box = Hive.box<String>(bucket ?? _defaultBoxName);
    if (!box.isOpen) return null;
    return box.get(key);
  }

  static Future<void> clearBucket({required String bucket}) async {
    final box = getBoxSync(bucket);
    final keys = box.keys;
    await box.deleteAll(keys);
    await box.clear();
  }
  //endregion

  static Future<void> initial({
    int? version,
    String? path,
    int? timeInterval,
    String? supperFilter,
    List<String>? initialOpened,
    Function(dynamic second)? onError,
  }) async {
    if (path != null) {
      Hive.init(path);
    } else {
      await Hive.initFlutter();
    }

    await initialOpenBucket(_defaultBoxName);

    for (final boxName in initialOpened ?? <String>[]) {
      await initialOpenBucket(boxName);
    }

    _version = version ?? 1;
    time = timeInterval ?? 60;
    mSupperFilter = supperFilter;
    onErrorFun = onError;

    if (await getFromBucket(key: _versionKey) != _version.toString()) {
      await clearCash(_defaultBoxName);
      final box = await getBox(_defaultBoxName);
      await box.put(_versionKey, _version.toString());
    }
  }

  static void setSupperFilter(String supperFilter) => mSupperFilter = supperFilter;

  static Future<void> _updateLatestUpdateBox(MCubitCache mCubit) async {
    final updateBox = await getBox(latestUpdateBox);
    await updateBox.put(
      '${mCubit.fixedName}${mCubit.filter}',
      DateTime.now().toIso8601String(),
    );
  }

  static Future<void> saveData(
    MCubitCache mCubit, {
    required dynamic data,
    bool clearId = true,
    List<int>? sortKey,
  }) async {
    await _updateLatestUpdateBox(mCubit);

    final box = await getBox(mCubit.nameCache);
    final id = _getIdParam(data);
    final haveId = id.isNotEmpty;

    final key = CacheKey(
      id: id,
      sort: 0,
      filter: mCubit.filter,
      version: _version,
    );

    if (data is Iterable) {
      if (clearId) await clearKeysId(box: box, key: key);

      final map = <dynamic, String>{};

      data.forEachIndexed(
        (i, e) {
          final itemId = haveId ? _getIdParam(e) : '';
          final keyString = key.copyWith(id: itemId, sort: sortKey?[i] ?? i).jsonString;
          map[keyString] = jsonEncode(e);
        },
      );

      await box.putAll(map);
      return;
    }

    await box.put(key.jsonString, jsonEncode(data));
  }

  static Future<Iterable<dynamic>?> addOrUpdate(
    MCubitCache mCubit, {
    required List<dynamic> data,
  }) async {
    final cacheKey = CacheKey(
      id: getIdFromData(data),
      filter: mCubit.filter,
      version: _version,
      sort: 0,
    );

    if (cacheKey.id.isEmpty) return null;

    final box = await getBox(mCubit.nameCache);
    final Map<dynamic, String> mapUpdate = {};

    try {
      for (final d in data) {
        final item = jsonEncode(d);
        final itemId = _getIdParam(d);

        final key = box.keys.firstWhereOrNull((e) {
          final decoded = jsonDecode(e);
          return decoded['i'] == itemId && (decoded['f'] ?? '') == cacheKey.filter;
        });

        if (key != null) {
          mapUpdate[key] = item;
        } else {
          cacheKey.id = itemId;
          mapUpdate[cacheKey.jsonString] = item;
        }
      }
    } catch (e) {
      _logger.e('addOrUpdate: $e');
    }

    await box.putAll(mapUpdate);
    return await getList(mCubit);
  }

  static Future<Iterable<dynamic>?> delete(
    MCubitCache mCubit, {
    required List<String> ids,
  }) async {
    final box = await getBox(mCubit.nameCache);

    for (final e in box.keys) {
      try {
        final json = jsonDecode(e);
        if (ids.contains(json['i'])) {
          await box.delete(e);
        }
      } catch (_) {}
    }

    return await getList(mCubit);
  }

  static Future<void> clearKeysId({
    required Box<String> box,
    required CacheKey key,
  }) async {
    final keys = key.filter.isEmpty
        ? box.keys
        : box.keys.where((e) {
            try {
              return (jsonDecode(e)['f'] ?? '') == key.filter;
            } catch (_) {
              return false;
            }
          });

    await box.deleteAll(keys);
  }

  static Future<Iterable<dynamic>> getList(
    MCubitCache mCubit, {
    bool Function(Map<String, dynamic> json)? deleteFunction,
    bool? reversed,
  }) async {
    final box = await getBox(mCubit.nameCache);
    final listKeys = await _findKey(mCubit, reversed: reversed, deleteFunction: deleteFunction);
    return listKeys.map((i) => jsonDecode(box.getAt(i) ?? '{}'));
  }

  static Future<dynamic> getData(MCubitCache mCubit) async {
    final box = await getBox(mCubit.nameCache);
    final listKeys = await _findKey(mCubit, firstFound: true);
    return listKeys.map((i) => jsonDecode(box.getAt(i) ?? '{}')).firstOrNull;
  }

  static Future<Box<String>> getBox(String name) async {
    return Hive.isBoxOpen(name) ? Hive.box<String>(name) : await Hive.openBox<String>(name);
  }

  static Box<String> getBoxSync(String name) {
    return Hive.box<String>(name);
  }

  static Future<List<int>> _findKey(
    MCubitCache mCubit, {
    bool firstFound = false,
    bool? reversed,
    bool Function(Map<String, dynamic> json)? deleteFunction,
  }) async {
    final box = await getBox(mCubit.nameCache);
    final listKeys = box.keys.toList();
    final myMap = <int, int>{};

    for (var i = 0; i < listKeys.length; i++) {
      try {
        final keyCache = CacheKey.fromJson(jsonDecode(listKeys[i]));

        if (keyCache.version != _version) {
          await clearCash(mCubit.nameCache);
          break;
        }

        if (deleteFunction != null) {
          if (deleteFunction.call(jsonDecode(box.getAt(i) ?? '{}'))) {
            listKeys.removeAt(i);
            await box.deleteAt(i);
            i -= 1;
            continue;
          }
        }

        if (keyCache.filter == mCubit.filter) {
          myMap[i] = keyCache.sort;
          if (firstFound) break;
        }
      } catch (e) {
        _logger.e('_findKey: $e');
        listKeys.removeAt(i);
        await box.deleteAt(i);
        i -= 1;
      }
    }

    if (myMap.isEmpty) return [];

    final sortedEntries = myMap.entries.toList()
      ..sort((e1, e2) {
        if (reversed == true) {
          return e2.value.compareTo(e1.value);
        } else {
          return e1.value.compareTo(e2.value);
        }
      });

    return sortedEntries.map((e) => e.key).toList();
  }

  static Future<DateTime?> _latestDate(MCubitCache mCubit) async {
    final box = await getBox(latestUpdateBox);
    return DateTime.tryParse(box.get('${mCubit.fixedName}${mCubit.filter}') ?? '');
  }

  static Future<NeedUpdateEnum> needGetData(MCubitCache mCubit) async {
    final latest = await _latestDate(mCubit);
    if (latest == null) return NeedUpdateEnum.withLoading;

    final keyFounded = await _findKey(mCubit, firstFound: true);
    if (keyFounded.isEmpty) return NeedUpdateEnum.withLoading;

    final d = DateTime.now().difference(latest).inSeconds.abs();
    if (d > mCubit.timeInterval) return NeedUpdateEnum.noLoading;

    return NeedUpdateEnum.no;
  }

  static String getIdFromData(dynamic data) {
    return _getIdParam(data);
  }

  static String _getIdParam(dynamic data) {
    try {
      if (data is Map) return data['id']?.toString() ?? '';

      if (data is Iterable) {
        if (data.isEmpty) return '';
        final firstItem = data.first;
        if (firstItem is String) return firstItem;
        if (firstItem is Map) return firstItem['id']?.toString() ?? '';
        return (firstItem.id?.toString().isBlank ?? true) ? '' : firstItem.id.toString();
      } else {
        return (data.id?.toString().isBlank ?? true) ? '' : data.id.toString();
      }
    } catch (_) {
      return '';
    }
  }

  static Future<void> clearCash(String name) async {
    final box = await getBox(name);
    await box.deleteAll(box.keys);
    await box.flush();
  }
}

class CacheKey {
  CacheKey({
    required this.id,
    required this.filter,
    required this.version,
    required this.sort,
  }) {
    filter = filter.replaceAll('null', '');
  }

  String id;
  String filter;
  final num version;
  final int sort;

  factory CacheKey.fromJson(Map<String, dynamic> json) {
    return CacheKey(
      id: json['i']?.toString() ?? '',
      filter: json['f']?.toString() ?? '',
      version: json['v'] ?? 0,
      sort: json['s'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'i': id,
        if (filter.isNotEmpty) 'f': filter,
        if (version != 0) 'v': version,
        if (sort != 0) 's': sort,
      };

  String get jsonString => jsonEncode(toJson());

  CacheKey copyWith({
    String? id,
    String? filter,
    num? version,
    int? sort,
  }) {
    return CacheKey(
      id: id ?? this.id,
      filter: filter ?? this.filter,
      version: version ?? this.version,
      sort: sort ?? this.sort,
    );
  }
}

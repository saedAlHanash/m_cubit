import 'dart:async';
import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';

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

  static String formatKey({
    required String filter,
    required String id,
    int sort = 0,
  }) {
    final cleanFilter = filter.replaceAll(':', '_');
    return '$cleanFilter:$sort:$id';
  }

  static ({String filter, int sort, String id}) parseKey(String key) {
    final parts = key.split(':');
    if (parts.length >= 3) {
      return (
        filter: parts[0],
        sort: int.tryParse(parts[1]) ?? 0,
        id: parts.sublist(2).join(':'),
      );
    }
    // Fallback for legacy JSON-encoded keys if any
    try {
      final decoded = jsonDecode(key);
      return (
        filter: decoded['f']?.toString() ?? '',
        sort: decoded['s'] is int ? decoded['s'] as int : 0,
        id: decoded['i']?.toString() ?? '',
      );
    } catch (_) {
      return (filter: '', sort: 0, id: key);
    }
  }

  static Future<void> _updateLatestUpdate({
    required String boxName,
    required String filter,
  }) async {
    final updateBox = await getBox(latestUpdateBox);
    await updateBox.put(
      '$boxName$filter',
      DateTime.now().toIso8601String(),
    );
  }

  static Future<void> saveData({
    required String boxName,
    required String filter,
    required dynamic data,
    bool clearId = true,
    List<int>? sortKey,
  }) async {
    await _updateLatestUpdate(boxName: boxName, filter: filter);

    final box = await getBox(boxName);
    final id = _getIdParam(data);
    final haveId = id.isNotEmpty;

    if (data is Iterable) {
      if (clearId) {
        await clearFilterKeys(box: box, filter: filter);
      }

      final map = <String, String>{};
      var index = 0;
      for (final item in data) {
        final itemId = haveId ? _getIdParam(item) : '';
        final sortOrder = (sortKey != null && sortKey.length > index) ? sortKey[index] : index;
        final keyString = formatKey(filter: filter, id: itemId, sort: sortOrder);
        map[keyString] = jsonEncode(item);
        index++;
      }

      await box.putAll(map);
      return;
    }

    final keyString = formatKey(filter: filter, id: id, sort: 0);
    await box.put(keyString, jsonEncode(data));
  }

  static Future<Iterable<dynamic>?> addOrUpdate({
    required String boxName,
    required String filter,
    required List<dynamic> data,
  }) async {
    final box = await getBox(boxName);
    final Map<String, String> mapUpdate = {};

    try {
      for (final d in data) {
        final itemJson = jsonEncode(d);
        final itemId = _getIdParam(d);
        if (itemId.isEmpty) continue;

        final existingKey = box.keys.cast<String?>().firstWhere(
          (k) {
            if (k == null) return false;
            final parsed = parseKey(k);
            return parsed.id == itemId && parsed.filter == filter;
          },
          orElse: () => null,
        );

        if (existingKey != null) {
          mapUpdate[existingKey] = itemJson;
        } else {
          final newKey = formatKey(filter: filter, id: itemId, sort: 0);
          mapUpdate[newKey] = itemJson;
        }
      }
    } catch (e) {
      _logger.e('addOrUpdate error: $e');
    }

    if (mapUpdate.isNotEmpty) {
      await box.putAll(mapUpdate);
    }

    return await getList(boxName: boxName, filter: filter);
  }

  static Future<Iterable<dynamic>?> delete({
    required String boxName,
    required String filter,
    required List<String> ids,
  }) async {
    final box = await getBox(boxName);
    final keysToDelete = <String>[];

    for (final k in box.keys) {
      if (k is! String) continue;
      final parsed = parseKey(k);
      if (ids.contains(parsed.id)) {
        keysToDelete.add(k);
      }
    }

    if (keysToDelete.isNotEmpty) {
      await box.deleteAll(keysToDelete);
    }

    return await getList(boxName: boxName, filter: filter);
  }

  static Future<void> clearFilterKeys({
    required Box<String> box,
    required String filter,
  }) async {
    final keysToDelete = box.keys.where((k) {
      if (k is! String) return false;
      if (filter.isEmpty) return true;
      final parsed = parseKey(k);
      return parsed.filter == filter;
    }).toList();

    await box.deleteAll(keysToDelete);
  }

  static Future<Iterable<dynamic>> getList({
    required String boxName,
    required String filter,
    bool Function(Map<String, dynamic> json)? deleteFunction,
    bool? reversed,
  }) async {
    final box = await getBox(boxName);
    final sortedIndices = await _findKeyIndices(
      boxName: boxName,
      filter: filter,
      reversed: reversed,
      deleteFunction: deleteFunction,
    );

    return sortedIndices.map((i) {
      final val = box.getAt(i);
      if (val == null) return <String, dynamic>{};
      try {
        return jsonDecode(val);
      } catch (_) {
        return <String, dynamic>{};
      }
    });
  }

  static Future<dynamic> getData({
    required String boxName,
    required String filter,
  }) async {
    final box = await getBox(boxName);
    final sortedIndices = await _findKeyIndices(
      boxName: boxName,
      filter: filter,
      firstFound: true,
    );

    if (sortedIndices.isEmpty) return null;
    final val = box.getAt(sortedIndices.first);
    if (val == null) return null;
    try {
      return jsonDecode(val);
    } catch (_) {
      return null;
    }
  }

  static Future<Box<String>> getBox(String name) async {
    return Hive.isBoxOpen(name) ? Hive.box<String>(name) : await Hive.openBox<String>(name);
  }

  static Box<String> getBoxSync(String name) {
    return Hive.box<String>(name);
  }

  static Future<List<int>> _findKeyIndices({
    required String boxName,
    required String filter,
    bool firstFound = false,
    bool? reversed,
    bool Function(Map<String, dynamic> json)? deleteFunction,
  }) async {
    final box = await getBox(boxName);
    final listKeys = box.keys.toList();
    final indexSortMap = <int, int>{};

    for (var i = 0; i < listKeys.length; i++) {
      final rawKey = listKeys[i];
      if (rawKey is! String) continue;

      try {
        final parsed = parseKey(rawKey);

        if (deleteFunction != null) {
          final content = box.getAt(i);
          if (content != null && deleteFunction(jsonDecode(content))) {
            listKeys.removeAt(i);
            await box.deleteAt(i);
            i -= 1;
            continue;
          }
        }

        if (parsed.filter == filter) {
          indexSortMap[i] = parsed.sort;
          if (firstFound) break;
        }
      } catch (e) {
        _logger.e('_findKeyIndices error: $e');
      }
    }

    if (indexSortMap.isEmpty) return [];

    final sortedEntries = indexSortMap.entries.toList()
      ..sort((e1, e2) {
        if (reversed == true) {
          return e2.value.compareTo(e1.value);
        } else {
          return e1.value.compareTo(e2.value);
        }
      });

    return sortedEntries.map((e) => e.key).toList();
  }

  static Future<DateTime?> latestDate({
    required String boxName,
    required String filter,
  }) async {
    final box = await getBox(latestUpdateBox);
    return DateTime.tryParse(box.get('$boxName$filter') ?? '');
  }

  static Future<NeedUpdateEnum> needGetData({
    required String boxName,
    required String filter,
    required int timeInterval,
  }) async {
    final latest = await latestDate(boxName: boxName, filter: filter);
    if (latest == null) return NeedUpdateEnum.withLoading;

    final keyFounded = await _findKeyIndices(
      boxName: boxName,
      filter: filter,
      firstFound: true,
    );
    if (keyFounded.isEmpty) return NeedUpdateEnum.withLoading;

    final diffInSeconds = DateTime.now().difference(latest).inSeconds.abs();
    if (diffInSeconds > timeInterval) return NeedUpdateEnum.noLoading;

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

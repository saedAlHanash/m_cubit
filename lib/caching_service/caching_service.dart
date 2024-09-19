import 'dart:async';
import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';

import '../abstraction.dart';
import '../util.dart';
import 'package:collection/collection.dart';

var loggerObject = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    // number of method calls to be displayed
    errorMethodCount: 0,
    // number of method calls if stacktrace is provided
    lineLength: 300,
    // width of the output
    colors: true,
    // Colorful log messages
    printEmojis: false,
    // Print an emoji for each log message
    printTime: false,
  ),
);

const latestUpdateBox = 'latestUpdateBox';
var _version = 1;

var time = 60;

void Function(dynamic second)? onErrorFun;

class CachingService {
  static Future<void> initial({
    int? version,
    int? timeInterval,
    required Function(dynamic second)? onError,
  }) async {
    _version = version ?? 1;
    time = timeInterval ?? 180;
    onErrorFun = onError;
    await Hive.initFlutter();
  }

  static Future<void> updateLatestUpdateBox(String name) async {
    final boxUpdate = await getBox(latestUpdateBox);

    await boxUpdate.put(name, DateTime.now().toIso8601String());
  }

  static Future<void> sortData(
    MCubit mCubit, {
    required dynamic data,
  }) async {
    await updateLatestUpdateBox(mCubit.nameCache);
    final box = await mCubit.box;

    final id = _getIdParam(data);
    final haveId = id.isNotEmpty;

    final key = CacheKey(
      id: '',
      sort: 0,
      filter: mCubit.filter,
      version: _version,
    );

    if (data is Iterable) {
      await clearKeysId(box: box, key: key);

      final map = <dynamic, String>{};

      data.forEachIndexed(
        (i, e) {
          final id = haveId ? _getIdParam(e) : '';

          final keyString = key.copyWith(id: id, sort: i).jsonString;

          map[keyString] = jsonEncode(e);
        },
      );

      await box.putAll(map);

      return;
    }

    final keyString = key.copyWith(id: id).jsonString;

    await box.put(keyString, jsonEncode(data));
  }

  static Future<Iterable<dynamic>?> addOrUpdate(
    MCubit mCubit, {
    required List<dynamic> data,
  }) async {
    final key = CacheKey(
      id: getIdFromData(data),
      filter: mCubit.filter,
      version: _version,
      sort: 0,
    );

    if (key.id.isEmpty) return null;

    final box = await mCubit.box;

    for (var d in data) {
      final keys = box.keys.where((e) => jsonDecode(e)['i'] == d.id);

      final item = jsonEncode(d);

      final mapUpdate = Map.fromEntries(keys.map((key) => MapEntry(key, item)));

      //if not found the operation is add
      if (mapUpdate.isEmpty) mapUpdate[key.jsonString] = item;

      await box.putAll(mapUpdate);
    }

    return await getList(mCubit);
  }

  static Future<Iterable<dynamic>?> delete(
    MCubit mCubit, {
    required List<String> ids,
  }) async {
    final box = await mCubit.box;

    for (var e in box.keys) {
      final json = jsonDecode(e);
      if (ids.contains(json['i'])) {
        loggerObject.e('delete${json['i']}');
        await box.delete(e);
      }
    }

    return await getList(mCubit);
  }

  static Future<void> clearKeysId({
    required Box<String> box,
    required CacheKey key,
  }) async {
    final keys = box.keys.where((e) => jsonDecode(e)['f'] == key.filter);

    await box.deleteAll(keys);
  }

  static Future<Iterable<dynamic>> getList(MCubit mCubit) async {
    final box = await mCubit.box;

    final listKeys = await _findKey(mCubit);

    return listKeys.map((i) => jsonDecode(box.getAt(i) ?? '{}'));
  }

  static Future<dynamic> getData(MCubit mCubit) async {
    final box = await mCubit.box;
    final listKeys = await _findKey(mCubit, firstFound: true);

    return listKeys.map((i) => jsonDecode(box.getAt(i) ?? '{}')).firstOrNull;
  }

  static Future<Box<String>> getBox(String name) async {
    return Hive.isBoxOpen(name)
        ? Hive.box<String>(name)
        : await Hive.openBox<String>(name);
  }

  static Future<List<int>> _findKey(MCubit mCubit, {bool firstFound = false}) async {
    final box = await mCubit.box;

    final listKeys = box.keys.toList();

    final myMap = <int, int>{};

    for (var i = 0; i < listKeys.length; i++) {
      try {
        final keyCache = CacheKey.fromJson(jsonDecode(listKeys[i]));

        if (keyCache.version != _version) {
          listKeys.removeAt(i);
          await box.deleteAt(i);
          i -= 1;
          continue;
        }

        if (keyCache.filter == mCubit.filter) {
          myMap[i] = keyCache.sort;
          if (firstFound) break;
        }
      } catch (e) {
        listKeys.removeAt(i);
        await box.deleteAt(i);
        i -= 1;
        loggerObject.e('CacheKey.fromJson $e');
      }
    }

    var sortedEntries = myMap.entries.toList()
      ..sort((e1, e2) => e1.value.compareTo(e2.value));

    return sortedEntries.map((e) => e.key).toList();
  }

  static Future<DateTime?> _latestDate(String name) async {
    return DateTime.tryParse((await getBox(latestUpdateBox)).get(name) ?? '');
  }

  static Future<NeedUpdateEnum> needGetData(MCubit mCubit) async {
    //latest update
    final latest = await _latestDate(mCubit.nameCache);

    //if null then this is first time -LOADING-
    if (latest == null) return NeedUpdateEnum.withLoading;

    //find filter key
    final keyFounded = await _findKey(mCubit, firstFound: true);

    //if empty then this is first time with this key -LOADING-
    if (keyFounded.isEmpty) return NeedUpdateEnum.withLoading;

    // if found check time expiration
    final d = DateTime.now().difference(latest).inSeconds.abs();

    // Time is Expired..?!  -NO_LOADING-
    if (d > mCubit.timeInterval) return NeedUpdateEnum.noLoading;

    //  Time not expire call api
    return NeedUpdateEnum.no;
  }

  static String getIdFromData(dynamic data) {
    return _getIdParam(data);
  }

  static String _getIdParam(dynamic data) {
    try {
      // If passing list of items
      if (data is Iterable) {
        // If no items
        if (data.isEmpty) return '';

        // If first item string that meaning is the list is [id,id,id...]
        // Then return first id
        if (data.first is String) return data.first;

        // Get first item and get param .id and convert to string and check if it not blank
        return (data.first.id.toString().isBlank) ? '' : data.first.id.toString();
      } else {
        // Not Lest then it`s single item
        return (data.id.toString().isBlank) ? '' : data.id.toString();
      }
    } catch (e) {
      return '';
    }
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

  final String id;
  String filter;
  final num version;
  final int sort;

  factory CacheKey.fromJson(Map<String, dynamic> json) {
    return CacheKey(
      id: json["i"] ?? "",
      filter: json["f"] ?? "",
      version: json["v"] ?? 0,
      sort: json["s"] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        "i": id,
        "f": filter,
        "v": version,
        "s": sort,
      };

  String get jsonString => jsonEncode(this);

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

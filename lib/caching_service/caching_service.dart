import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../abstraction.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:logger/logger.dart';

import '../util.dart';

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

class CachingService {
  static Future<void> initial({
    int? version,
    int? timeInterval,
  }) async {
    _version = version ?? 1;
    time = timeInterval ?? 180;
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

    final haveId = _getIdParam(data).isNotEmpty;

    final key = CacheKey(
      id: '',
      filter: mCubit.filter,
      version: _version,
    );

    final box = await mCubit.box;

    if (data is Iterable) {
      await clearKeysId(box: box, filter: key);
      final map = <dynamic, String>{};

      for (var e in data) {
        final id = haveId ? _getIdParam(e) : '';

        final keyString = key.copyWith(id: id).jsonString;

        map[keyString] = jsonEncode(e);
      }

      await box.putAll(map);

      return;
    }

    final keyString = key.copyWith(id: haveId ? _getIdParam(data) : '').jsonString;

    await box.put(keyString, jsonEncode(data));
  }

  static Future<Iterable<dynamic>?> addOrUpdate(
    MCubit mCubit, {
    required List<dynamic> data,
  }) async {
    final key =
        CacheKey(id: getIdFromData(data), filter: mCubit.filter, version: _version);

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

//{\"i\":\"5ec010ec-a9ba-41ae-9360-08dcd0c07c0f\",\"f\":\"\",\"v\":6}
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
    required CacheKey filter,
  }) async {
    final keys = box.keys.where((e) => jsonDecode(e)['f'] == filter.filter);

    await box.deleteAll(keys);
  }

  static Future<Iterable<dynamic>> getList(MCubit mCubit) async {
    final box = await mCubit.box;

    final listKeys = await _findKey(mCubit);

    return listKeys.map((e) => jsonDecode(box.get(e) ?? '{}'));
  }

  static Future<dynamic> getData(MCubit mCubit) async {
    final box = await mCubit.box;
    final listKeys = await _findKey(mCubit, firstFound: true);

    return listKeys.map((e) => jsonDecode(box.get(e) ?? '{}')).firstOrNull;
  }

  static Future<Box<String>> getBox(String name) async {
    return Hive.isBoxOpen(name)
        ? Hive.box<String>(name)
        : await Hive.openBox<String>(name);
  }

  static Future<List<String>> _findKey(MCubit mCubit, {bool firstFound = false}) async {
    final box = await mCubit.box;

    final listKeys = box.keys.toList();
    final list = <String>[];

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
          list.add(listKeys[i]);
          if (firstFound) break;
        }
      } catch (e) {
        listKeys.removeAt(i);
        await box.deleteAt(i);
        i -= 1;
        loggerObject.e('CacheKey.fromJson $e');
      }
    }
    return list;
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
      if (data is List) {
        if (data.first is String) return data.first;
        return (data.first.id.toString().isBlank) ? '-' : data.first.id.toString();
      } else {
        return (data.id.toString().isBlank) ? '-' : data.id.toString();
      }
    } catch (e) {
      return '-1';
    }
  }
}

class CacheKey {
  CacheKey({
    required this.id,
    required this.filter,
    required this.version,
  }) {
    filter = filter.replaceAll('null', '');
  }

  final String id;
  String filter;
  final num version;

  factory CacheKey.fromJson(Map<String, dynamic> json) {
    return CacheKey(
      id: json["i"] ?? "",
      filter: json["f"] ?? "",
      version: json["v"] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        "i": id,
        "f": filter,
        "v": version,
      };

  String get jsonString => jsonEncode(this);

  CacheKey copyWith({
    String? id,
    String? filter,
    num? version,
  }) {
    return CacheKey(
      id: id ?? this.id,
      filter: filter ?? this.filter,
      version: version ?? this.version,
    );
  }
}

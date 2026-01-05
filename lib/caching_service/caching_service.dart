// استيراد المكتبات اللازمة
import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';

import '../abstraction.dart';
import '../util.dart';

// كائن لتسجيل الأخطاء والملاحظات
var _loggerObject = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    // عدد استدعاءات الدوال التي سيتم عرضها
    errorMethodCount: 0,
    // عدد استدعاءات الدوال في حال وجود تتبع للأخطاء
    lineLength: 300,
    // عرض المخرجات
    colors: true,
    // رسائل سجل ملونة
    printEmojis: false,
  ),
);

// اسم الصندوق الذي يخزن آخر تحديث
String get latestUpdateBox => '${mSupperFilter ?? ''}-latestUpdateBox';

// إصدار الكاش
var _version = 1;

// مدة صلاحية الكاش بالثواني
var time = 60;

// فلتر إضافي يمكن استخدامه
String? mSupperFilter;

// دالة لمعالجة الأخطاء
void Function(dynamic state)? onErrorFun;

// خدمة التخزين المؤقت
class CachingService {
  // تهيئة خدمة التخزين المؤقت
  static Future<void> initial({
    int? version,
    String? path,
    int? timeInterval,
    String? supperFilter,
    required Function(dynamic second)? onError,
  }) async {
    _version = version ?? 1;

    time = timeInterval ?? 180;

    mSupperFilter = supperFilter;

    onErrorFun = onError;

    await Hive.initFlutter(path);
  }

  // تعيين الفلتر الإضافي
  static void setSupperFilter(String supperFilter) => mSupperFilter = supperFilter;

  // تحديث وقت آخر تحديث للكائن
  static Future<void> _updateLatestUpdateBox(MCubitCache mCubit) async {
    await (await getBox(latestUpdateBox)).put(
      '${mCubit.fixedName}${mCubit.filter}',
      DateTime.now().toIso8601String(),
    );
  }

  // حفظ البيانات في الكاش
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
        (i, e) async {
          final id = haveId ? _getIdParam(e) : '';

          if (clearId) {
            final keyString = key.copyWith(id: id, sort: sortKey?[i] ?? i).jsonString;
            map[keyString] = jsonEncode(e);
          } else {
            final keyString = key.copyWith(id: id).jsonString;
            map[keyString] = jsonEncode(e);
          }
        },
      );

      await box.putAll(map);

      return;
    }

    await box.put(key.jsonString, jsonEncode(data));
  }

  // إضافة أو تحديث البيانات في الكاش
  static Future<Iterable<dynamic>?> addOrUpdate(
    MCubitCache mCubit, {
    required List<dynamic> data,
  }) async {
    final key = CacheKey(
      id: getIdFromData(data),
      filter: mCubit.filter,
      version: _version,
      sort: 0,
    );

    if (key.id.isEmpty) return null;

    final box = await getBox(mCubit.nameCache);

    for (var d in data) {
      final keys = box.keys.where((e) => jsonDecode(e)['i'] == d.id && (jsonDecode(e)['f'] ?? '') == key.filter);

      final item = jsonEncode(d);

      final mapUpdate = Map.fromEntries(keys.map((key) => MapEntry(key, item)));

      // إذا لم يتم العثور على العنصر، تكون العملية إضافة
      if (mapUpdate.isEmpty) mapUpdate[key.jsonString] = item;

      await box.putAll(mapUpdate);
    }

    return await getList(mCubit);
  }

  // حذف البيانات من الكاش
  static Future<Iterable<dynamic>?> delete(
    MCubitCache mCubit, {
    required List<String> ids,
  }) async {
    final box = await getBox(mCubit.nameCache);

    for (var e in box.keys) {
      final json = jsonDecode(e);
      if (ids.contains(json['i'])) {
        _loggerObject.e('delete: ${json['i']}');
        await box.delete(e);
      }
    }

    return await getList(mCubit);
  }

  // مسح المفاتيح حسب المعرف
  static Future<void> clearKeysId({
    required Box<String> box,
    required CacheKey key,
  }) async {
    final keys = key.filter.isEmpty ? box.keys : box.keys.where((e) => (jsonDecode(e)['f'] ?? '') == key.filter);

    await box.deleteAll(keys);
  }

  // جلب قائمة من الكاش
  static Future<Iterable<dynamic>> getList(
    MCubitCache mCubit, {
    bool Function(Map<String, dynamic> json)? deleteFunction,
    bool? reversed,
  }) async {
    final box = await getBox(mCubit.nameCache);

    final listKeys = await _findKey(mCubit, reversed: reversed, deleteFunction: deleteFunction);

    return listKeys.map((i) => jsonDecode(box.getAt(i) ?? '{}'));
  }

  // جلب بيانات من الكاش
  static Future<dynamic> getData(MCubitCache mCubit) async {
    final box = await getBox(mCubit.nameCache);
    final listKeys = await _findKey(mCubit, firstFound: true);

    return listKeys.map((i) => jsonDecode(box.getAt(i) ?? '{}')).firstOrNull;
  }

  // جلب صندوق Hive
  static Future<Box<String>> getBox(String name) async {
    return Hive.isBoxOpen(name) ? Hive.box<String>(name) : await Hive.openBox<String>(name);
  }

  // البحث عن المفتاح في الكاش
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
        _loggerObject.e('_findKey: $e');
        listKeys.removeAt(i);
        await box.deleteAt(i);
        i -= 1;
      }
    }

    if (myMap.isEmpty) return [];

    var sortedEntries = myMap.entries.toList()
      ..sort((e1, e2) {
        if (reversed == true) {
          return e2.value.compareTo(e1.value);
        } else {
          return e1.value.compareTo(e2.value);
        }
      });

    return sortedEntries.map((e) => e.key).toList();
  }

  // جلب تاريخ آخر تحديث
  static Future<DateTime?> _latestDate(MCubitCache mCubit) async {
    return DateTime.tryParse((await getBox(latestUpdateBox)).get('${mCubit.fixedName}${mCubit.filter}') ?? '');
  }

  // التحقق مما إذا كانت هناك حاجة لجلب البيانات
  static Future<NeedUpdateEnum> needGetData(MCubitCache mCubit) async {
    // آخر تحديث
    final latest = await _latestDate(mCubit);

    // إذا كانت القيمة فارغة، فهذه هي المرة الأولى - تحميل
    if (latest == null) return NeedUpdateEnum.withLoading;

    // البحث عن مفتاح الفلتر
    final keyFounded = await _findKey(mCubit, firstFound: true);

    // إذا كانت القائمة فارغة، فهذه هي المرة الأولى مع هذا المفتاح - تحميل
    if (keyFounded.isEmpty) return NeedUpdateEnum.withLoading;

    // إذا تم العثور على المفتاح، تحقق من وقت انتهاء الصلاحية
    final d = DateTime.now().difference(latest).inSeconds.abs();

    // هل انتهت صلاحية الوقت؟ - لا يوجد تحميل
    if (d > mCubit.timeInterval) return NeedUpdateEnum.noLoading;

    // لم ينته وقت الصلاحية، قم باستدعاء الواجهة البرمجية
    return NeedUpdateEnum.no;
  }

  // جلب المعرف من البيانات
  static String getIdFromData(dynamic data) {
    return _getIdParam(data);
  }

  // جلب المعرف من البيانات
  static String _getIdParam(dynamic data) {
    try {
      // إذا تم تمرير كائن JSON
      if (data is Map) return data['id'] ?? '';

      // إذا تم تمرير قائمة من العناصر
      if (data is Iterable) {
        // إذا لم تكن هناك عناصر
        if (data.isEmpty) return '';

        // إذا كان العنصر الأول عبارة عن سلسلة نصية، فهذا يعني أن القائمة هي [معرف، معرف، معرف...]
        // ثم قم بإرجاع المعرف الأول
        if (data.first is String) return data.first;

        if (data.first is Map) return data.first['id'] ?? '';

        // جلب العنصر الأول والحصول على المعلمة .id وتحويلها إلى سلسلة نصية والتحقق من أنها ليست فارغة
        return (data.first.id.toString().isBlank) ? '' : data.first.id.toString();
      } else {
        // إذا لم تكن قائمة، فهذا يعني أنه عنصر واحد
        return (data.id.toString().isBlank) ? '' : data.id.toString();
      }
    } catch (e) {
      return '';
    }
  }

  // مسح الكاش
  static Future<void> clearCash(String name) async {
    final box = await getBox(name);
    await box.deleteAll(box.keys);
  }
}

// مفتاح الكاش
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
        if (id.isNotEmpty) "i": id,
        if (filter.isNotEmpty) "f": filter,
        if (version != 0) "v": version,
        if (sort != 0) "s": sort,
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

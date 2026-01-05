// استيراد المكتبات اللازمة
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:m_cubit/util.dart';

import 'caching_service/caching_service.dart';
import 'command.dart';

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

// حالات Cubit
enum CubitStatuses { init, loading, noLoading, done, error }

// عمليات CRUD لـ Cubit
enum CubitCrud { get, create, update, delete }

// الحالة المجردة لـ Cubit
abstract class AbstractState<T> extends Equatable {
  final CubitStatuses statuses;
  final CubitCrud cubitCrud;
  final String error;
  final T result;
  final FilterRequest? filterRequest;
  final dynamic request;
  final dynamic id;
  final dynamic createUpdateRequest;

  // الحصول على مفتاح الفلتر
  String get filter {
    final f = filterRequest?.getKey ?? request?.toString().getKey ?? id?.toString().getKey ?? '';
    return f;
  }

  const AbstractState({
    this.statuses = CubitStatuses.init,
    this.cubitCrud = CubitCrud.get,
    this.error = '',
    this.filterRequest,
    this.request,
    this.createUpdateRequest,
    this.id,
    required this.result,
  });

  // التحقق مما إذا كانت الحالة قيد التحميل
  bool get loading => statuses == CubitStatuses.loading;

  // التحقق مما إذا كانت الحالة لا تتطلب تحميل
  bool get noLoading => statuses == CubitStatuses.noLoading;

  // التحقق مما إذا كانت الحالة قد انتهت
  bool get done => statuses == CubitStatuses.done;

  // التحقق مما إذا كانت العملية هي إنشاء
  bool get create => cubitCrud == CubitCrud.create;

  // التحقق مما إذا كانت العملية هي تحديث
  bool get update => cubitCrud == CubitCrud.update;

  // التحقق مما إذا كانت العملية هي حذف
  bool get delete => cubitCrud == CubitCrud.delete;

  // التحقق مما إذا كانت البيانات فارغة
  bool get isDataEmpty => (statuses != CubitStatuses.loading) && (result is List) && ((result as List).isEmpty);
}

// Cubit مجرد
abstract class MCubit<AbstractState> extends Cubit<AbstractState> {
  MCubit(super.initialState);

  // اسم الكاش
  String get nameCache => '';

  // الفلتر
  String get filter => '';

  // الحالة الحالية
  dynamic get mState;

  // الفترة الزمنية
  int get timeInterval => time;

  // استخدام الفلتر الإضافي
  bool get withSupperFilet => true;

  // مفتاح الكاش
  MCubitCache get cacheKey => MCubitCache(
        nameCache: withSupperFilet ? '${mSupperFilter ?? ''}-$nameCache' : nameCache,
        filter: filter,
        timeInterval: timeInterval,
      );

  // التحقق مما إذا كانت هناك حاجة لجلب البيانات
  Future<NeedUpdateEnum> _needGetData() async {
    return await CachingService.needGetData(this.cacheKey);
  }

  // حفظ البيانات
  Future<void> saveData(
    dynamic data, {
    bool clearId = true,
    List<int>? sortKey,
    MCubitCache? cacheKey,
  }) async {
    await CachingService.saveData(
      cacheKey ?? this.cacheKey,
      data: data,
      clearId: clearId,
      sortKey: sortKey,
    );
  }

  // مسح الكاش
  Future<void> clearCash() async {
    await CachingService.clearCash(nameCache);
  }

  // إضافة أو تحديث البيانات
  Future<Iterable<dynamic>?> addOrUpdateDate(List<dynamic> data) async {
    return await CachingService.addOrUpdate(this.cacheKey, data: data);
  }

  // حذف البيانات
  Future<Iterable<dynamic>?> deleteDate(List<String> ids) async {
    return await CachingService.delete(this.cacheKey, ids: ids);
  }

  // جلب قائمة من الكاش
  Future<List<T>> getListCached<T>({
    required T Function(Map<String, dynamic>) fromJson,
    bool? reversed,
    bool Function(Map<String, dynamic> json)? deleteFunction,
    MCubitCache? cacheKey,
  }) async {
    final data = await CachingService.getList(
      cacheKey ?? this.cacheKey,
      deleteFunction: deleteFunction,
      reversed: reversed,
    );
    if (data.isEmpty) return [];
    return data.map((e) {
      try {
        return fromJson(e);
      } catch (e) {
        _loggerObject.e('convert json /$nameCache/: $e');
        return fromJson({});
      }
    }).toList();
  }

  // جلب بيانات من الكاش
  Future<T> getDataCached<T>({
    required T Function(Map<String, dynamic>) fromJson,
    MCubitCache? cacheKey,
  }) async {
    final json = await CachingService.getData(cacheKey ?? this.cacheKey);
    try {
      return fromJson(json);
    } catch (e) {
      _loggerObject.e('convert json /$nameCache/: $e');
      return fromJson({});
    }
  }

  // التحقق من الكاش
  Future<MapEntry<bool, dynamic>> checkCashed<T>({
    required dynamic state,
    required T Function(Map<String, dynamic>) fromJson,
    bool? newData,
    void Function(dynamic data, CubitStatuses emitState)? onSuccess,
  }) async {
    dynamic data;

    if (state.result is List) {
      data = await getListCached(fromJson: fromJson);
    } else {
      data = await getDataCached(fromJson: fromJson);
    }

    final mState = state.copyWith(result: data);

    if (newData == true || nameCache.isEmpty) {
      if (onSuccess != null) {
        onSuccess.call(data, CubitStatuses.loading);
      } else {
        emit(mState.copyWith(statuses: CubitStatuses.loading));
      }

      return MapEntry(false, mState);
    }

    try {
      final cacheType = await _needGetData();

      if (onSuccess != null) {
        onSuccess.call(data, cacheType.getState);
      } else {
        emit(mState.copyWith(statuses: cacheType.getState));
      }

      return MapEntry(cacheType == NeedUpdateEnum.no, mState);
    } catch (e) {
      _loggerObject.e('checkCashed  $nameCache: $e');

      return MapEntry(false, mState);
    }
  }

  // جلب البيانات بشكل مجرد
  Future<void> getDataAbstract<T>({
    required T Function(Map<String, dynamic>) fromJson,
    required dynamic state,
    required Function getDataApi,
    bool? newData,
    void Function(dynamic second)? onError,
    void Function(dynamic data, CubitStatuses emitState)? onSuccess,
  }) async {
    final cacheKey = this.cacheKey;

    final checkData = await checkCashed(
      state: state,
      fromJson: fromJson,
      newData: newData,
      onSuccess: onSuccess,
    );

    if (checkData.key) {
      _loggerObject.f('$nameCache stopped on cache \n ${cacheKey.filter}');
      return;
    }

    final pair = await getDataApi.call();

    if (pair.first == null) {
      if (isClosed) return;

      final s = checkData.value.copyWith(statuses: CubitStatuses.error, error: pair.second);

      emit(s);

      if (onError == null) {
        onErrorFun?.call(s);
      }
      onError?.call(pair.second);
    } else {
      await saveData(
        pair.first,
        cacheKey: cacheKey,
      );

      if (onSuccess != null) {
        onSuccess.call(pair.first, CubitStatuses.done);
      } else {
        if (isClosed) return;
        emit(checkData.value.copyWith(statuses: CubitStatuses.done, result: pair.first));
      }
    }
  }

  // جلب البيانات من الكاش
  Future<void> getFromCache<T>({
    required T Function(Map<String, dynamic>) fromJson,
    required dynamic state,
    required void Function(dynamic data) onSuccess,
  }) async {
    dynamic data;

    if (state.result is List) {
      data = await getListCached(fromJson: fromJson);
    } else {
      data = await getDataCached(fromJson: fromJson);
    }

    onSuccess.call(data);

    // emit(state.copyWith(result: data));
  }
}

// مفتاح الكاش
class MCubitCache {
  final String nameCache;
  final String filter;
  int timeInterval;

  // الحصول على الاسم الثابت
  String get fixedName => nameCache.replaceAll(mSupperFilter ?? '', '');

  MCubitCache({
    required this.nameCache,
    this.filter = '',
    this.timeInterval = -1,
  }) {
    if (timeInterval < 0) timeInterval = time;
  }
}

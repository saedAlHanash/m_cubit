import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:m_cubit/util.dart';

import 'caching_service/caching_service.dart';
import 'command.dart';

var _loggerObject = Logger(
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
  ),
);

enum CubitStatuses { init, loading, noLoading, done, error }

enum CubitCrud { get, create, update, delete }

abstract class AbstractState<T> extends Equatable {
  final CubitStatuses statuses;
  final CubitCrud cubitCrud;
  final String error;
  final T result;
  final PaginationMeta? meta;

  final dynamic request;
  final dynamic id;
  final dynamic createUpdateRequest;

  String get filter {
    final f = '${meta?.getKey ?? ''}${request?.toString().getKey ?? id?.toString().getKey ?? ''}';
    return f;
  }

  final ScrollController? scrollController;

  const AbstractState({
    this.statuses = CubitStatuses.init,
    this.cubitCrud = CubitCrud.get,
    this.error = '',
    this.meta,
    // this.filterRequest,
    this.request,
    this.createUpdateRequest,
    this.scrollController,
    this.id,
    required this.result,
  });

  bool get loading => statuses == CubitStatuses.loading;

  bool get noLoading => statuses == CubitStatuses.noLoading;

  bool get done => statuses == CubitStatuses.done;

  bool get create => cubitCrud == CubitCrud.create;

  bool get update => cubitCrud == CubitCrud.update;

  bool get delete => cubitCrud == CubitCrud.delete;

  bool get isDataEmpty => (statuses != CubitStatuses.loading) && (result is List) && ((result as List).isEmpty);
}

abstract class MCubit<T> extends Cubit<T> {
  MCubit(super.initialState);

  //region overwrite

  AbstractState? get mState => null;

  String get nameCache => '';

  String get filter => '';

  int get timeInterval => time;

  bool get withSupperFilet => true;

  Function()? get onNext => null;

  //endregion

  MCubitCache get cacheKey => MCubitCache(
        nameCache: withSupperFilet ? '${mSupperFilter ?? ''}-$nameCache' : nameCache,
        filter: filter,
        timeInterval: timeInterval,
      );

  Future<NeedUpdateEnum> _needGetData() async {
    return await CachingService.needGetData(cacheKey);
  }

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

  Future<void> clearCash() async {
    await CachingService.clearCash(nameCache);
  }

  Future<Iterable<dynamic>?> addOrUpdateDate(List<dynamic> data) async {
    return await CachingService.addOrUpdate(cacheKey, data: data);
  }

  Future<Iterable<dynamic>?> deleteDate(List<String> ids) async {
    return await CachingService.delete(cacheKey, ids: ids);
  }

  Future<List<R>> getListCached<R>({
    required R Function(Map<String, dynamic>) fromJson,
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

  Future<R> getDataCached<R>({
    required R Function(Map<String, dynamic>) fromJson,
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

  /// Chack if need to update data from server
  /// Emit data to state and if(onSuccess != null) just call it
  ///
  Future<MapEntry<bool, dynamic>> checkCashedIfStopOnCash<R>({
    required dynamic state,
    required R Function(Map<String, dynamic>) fromJson,
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

  Future<void> getDataAbstract<R>({
    required R Function(Map<String, dynamic>) fromJson,
    required dynamic state,
    required Function getDataApi,
    bool? newData,
    void Function(dynamic second)? onError,
    void Function(dynamic data, CubitStatuses emitState)? onSuccess,
  }) async {
    final cacheKey = this.cacheKey;

    //التحقق من ان الكاش يكفي
    final checkData = await checkCashedIfStopOnCash(
      state: state,
      fromJson: fromJson,
      newData: newData,
      onSuccess: onSuccess,
    );

    //الكاش كافي ولا داعي للذهاب لل سيرفر
    if (checkData.key) {
      _loggerObject.f('$nameCache stopped on cache \n ${cacheKey.filter}');
      return;
    }

    // اذهب لل سيرفر
    final pair = await getDataApi.call();

    if (isClosed) return;

    // يوجد خطا
    if (pair.first == null) {
      // ال checkData.value  هي State
      final s = checkData.value.copyWith(statuses: CubitStatuses.error, error: pair.second);

      emit(s);

      if (onError == null) onErrorFun?.call(s);

      onError?.call(pair.second);
    } else {
      if (!pair.second.toString().isBlank) {
        final meta = PaginationMeta.fromJson(jsonDecode(pair.second));
        await CachingService.addInBucket(bucket: 'meta', map: {filter: jsonEncode(meta.toJson())});
      }

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

  Future<void> getFromCache<R>({
    required R Function(Map<String, dynamic>) fromJson,
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

  void scrollListener() {
    final position = mState?.scrollController?.position;
    if (position == null) return;
    if (position.pixels >= (position.maxScrollExtent - 5)) {
      onNext?.call();
    }
  }

  Future<PaginationMeta> get getMeta async {
    final savedJson = (await CachingService.getFromBucket(bucket: 'meta', key: filter)) ?? '{}';
    return PaginationMeta.fromJson(jsonDecode(savedJson));
  }
}

class MCubitCache {
  final String nameCache;
  final String filter;
  int timeInterval;

  String get fixedName => nameCache.replaceAll(mSupperFilter ?? '', '');

  MCubitCache({
    required this.nameCache,
    this.filter = '',
    this.timeInterval = -1,
  }) {
    if (timeInterval < 0) timeInterval = time;
  }
}

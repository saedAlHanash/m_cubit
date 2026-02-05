import 'package:equatable/equatable.dart';
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
  final FilterRequest? filterRequest;
  final dynamic request;
  final dynamic id;
  final dynamic createUpdateRequest;

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

  bool get loading => statuses == CubitStatuses.loading;

  bool get noLoading => statuses == CubitStatuses.noLoading;

  bool get done => statuses == CubitStatuses.done;

  bool get create => cubitCrud == CubitCrud.create;

  bool get update => cubitCrud == CubitCrud.update;

  bool get delete => cubitCrud == CubitCrud.delete;

  bool get isDataEmpty => (statuses != CubitStatuses.loading) && (result is List) && ((result as List).isEmpty);
}

abstract class MCubit<AbstractState> extends Cubit<AbstractState> {
  MCubit(super.initialState);

  String get nameCache => '';

  String get filter => '';

  dynamic get mState;

  int get timeInterval => time;

  bool get withSupperFilet => true;

  MCubitCache get cacheKey => MCubitCache(
        nameCache: withSupperFilet ? '${mSupperFilter ?? ''}-$nameCache' : nameCache,
        filter: filter,
        timeInterval: timeInterval,
      );

  Future<NeedUpdateEnum> _needGetData() async {
    return await CachingService.needGetData(this.cacheKey);
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
    return await CachingService.addOrUpdate(this.cacheKey, data: data);
  }

  Future<Iterable<dynamic>?> deleteDate(List<String> ids) async {
    return await CachingService.delete(this.cacheKey, ids: ids);
  }

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
        return fromJson(e??{});
      } catch (e) {
        _loggerObject.e('convert json /$nameCache/: $e');
        return fromJson({});
      }
    }).toList();
  }

  Future<T> getDataCached<T>({
    required T Function(Map<String, dynamic>) fromJson,
    MCubitCache? cacheKey,
  }) async {
    final json = (await CachingService.getData(cacheKey ?? this.cacheKey)) ?? {};

    try {
      return fromJson(json);
    } catch (e) {
      _loggerObject.e('convert json /$nameCache/: $e');
      return fromJson({});
    }
  }

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

    // if ((data is! T)) {
    //   await clearCash();
    //   _loggerObject.e('Error type : ${T.toString()} / ${data.runtimeType}');
    //   return checkCashed(state: state, fromJson: fromJson, newData: newData, onSuccess: onSuccess);
    // }

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

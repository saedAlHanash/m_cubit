import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:hive/hive.dart';
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
    // Print an emoji for each log message
    printTime: false,
  ),
);

enum CubitStatuses { init, loading, done, error }

abstract class AbstractState<T> extends Equatable {
  final CubitStatuses statuses;
  final String error;
  final T result;
  final FilterRequest? filterRequest;
  final dynamic request;

  String get filter {
    final f = filterRequest?.getKey ?? request?.toString().getKey ?? '';
    _loggerObject.w(f);
    return f;
  }

  const AbstractState({
    this.statuses = CubitStatuses.init,
    this.error = '',
    this.filterRequest,
    this.request,
    required this.result,
  });

  bool get loading => statuses == CubitStatuses.loading;

  bool get done => statuses == CubitStatuses.done;

  bool get isDataEmpty =>
      (statuses != CubitStatuses.loading) &&
      (result is List) &&
      ((result as List).isEmpty);
}

abstract class MCubit<AbstractState> extends Cubit<AbstractState> {
  MCubit(super.initialState);

  String get nameCache => '';

  String get filter => '';

  int get timeInterval => time;

  MCubitCache get _cacheKey =>
      MCubitCache(nameCache: nameCache, filter: filter, timeInterval: timeInterval);

  Future<NeedUpdateEnum> _needGetData() async {
    return await CachingService.needGetData(this._cacheKey);
  }

  Future<void> saveData(
    dynamic data, {
    bool clearId = true,
    List<int>? sortKey,
    MCubitCache? cacheKey,
  }) async {
    await CachingService.saveData(
      cacheKey ?? this._cacheKey,
      data: data,
      clearId: clearId,
      sortKey: sortKey,
    );
  }

  Future<Iterable<dynamic>?> addOrUpdateDate(List<dynamic> data) async {
    return await CachingService.addOrUpdate(this._cacheKey, data: data);
  }

  Future<Iterable<dynamic>?> deleteDate(List<String> ids) async {
    return await CachingService.delete(this._cacheKey, ids: ids);
  }

  Future<List<T>> getListCached<T>({
    required T Function(Map<String, dynamic>) fromJson,
    bool? reversed,
    bool Function(Map<String, dynamic> json)? deleteFunction,
  }) async {
    final data = await CachingService.getList(
      this._cacheKey,
      deleteFunction: deleteFunction,
      reversed: reversed,
    );
    if (data.isEmpty) return [];
    return data.map((e) {
      try {
        return fromJson(e);
      } catch (e) {
        return fromJson({});
      }
    }).toList();
  }

  Future<T> _getDataCached<T>({
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final json = await CachingService.getData(this._cacheKey);
    try {
      return fromJson(json);
    } catch (e) {
      return fromJson({});
    }
  }

  Future<bool> checkCashed<T>({
    required dynamic state,
    required T Function(Map<String, dynamic>) fromJson,
    bool newData = false,
    void Function(dynamic data, CubitStatuses emitState)? onSuccess,
  }) async {
    if (newData || nameCache.isEmpty) {
      emit(state.copyWith(statuses: CubitStatuses.loading));
      return false;
    }

    try {
      final cacheType = await _needGetData();

      dynamic data;

      if (state.result is List) {
        data = await getListCached(fromJson: fromJson);
      } else {
        data = await _getDataCached(fromJson: fromJson);
      }

      if (onSuccess != null) {
        onSuccess.call(data, cacheType.getState);
      } else {
        emit(
          state.copyWith(
            result: data,
            statuses: cacheType.getState,
          ),
        );
      }

      if (cacheType == NeedUpdateEnum.no) return true;

      return false;
    } catch (e) {
      _loggerObject.e('checkCashed  $nameCache: $e');

      return false;
    }
  }

  Future<void> getDataAbstract<T>({
    required T Function(Map<String, dynamic>) fromJson,
    required dynamic state,
    required Function getDataApi,
    bool newData = false,
    void Function(dynamic second)? onError,
    void Function(dynamic data, CubitStatuses emitState)? onSuccess,
  }) async {
    final cacheKey = this._cacheKey;

    final checkData = await checkCashed(
      state: state,
      fromJson: fromJson,
      newData: newData,
      onSuccess: onSuccess,
    );

    if (checkData) {
      _loggerObject.f('$nameCache stopped on cache');
      return;
    }

    final pair = await getDataApi.call();

    if (pair.first == null) {
      if (isClosed) return;

      final s = state.copyWith(statuses: CubitStatuses.error, error: pair.second);

      emit(s);

      onErrorFun?.call(s);

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
        emit(state.copyWith(statuses: CubitStatuses.done, result: pair.first));
      }
    }
  }
}

class MCubitCache {
  final String nameCache;
  final String filter;
  int timeInterval;

  MCubitCache({
    required this.nameCache,
    this.filter = '',
    this.timeInterval = 0,
  }) {
    timeInterval = time;
  }
}

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:m_cubit/util.dart';

import 'caching_service/caching_service.dart';
import 'command.dart';

final Logger _logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 0,
    lineLength: 300,
    colors: true,
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
    return filterRequest?.getKey ?? request?.toString().getKey ?? id?.toString().getKey ?? '';
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

abstract class MCubit<S extends AbstractState<dynamic>> extends Cubit<S> {
  MCubit(super.initialState);

  /// The cache box identifier. Override this in your Cubit.
  String get nameCache => '';

  /// Unique filter string for cache segregation.
  String get filter => state.filter;

  /// Clear existing cached records on full save if true.
  bool get clearIds => true;

  /// Legacy getter for backward compatibility.
  AbstractState get mState => state;

  /// Time interval for cache expiration in seconds.
  int get timeInterval => time;

  /// Whether to prefix cache name with global super filter.
  bool get withSupperFilet => true;

  /// Computed actual cache box name taking super filter into account.
  String get resolvedCacheBox => withSupperFilet && mSupperFilter != null && mSupperFilter!.isNotEmpty
      ? '$mSupperFilter-$nameCache'
      : nameCache;

  Future<NeedUpdateEnum> _needGetData() async {
    return await CachingService.needGetData(
      boxName: resolvedCacheBox,
      filter: filter,
      timeInterval: timeInterval,
    );
  }

  Future<void> saveData(
    dynamic data, {
    bool? clearId,
    List<int>? sortKey,
    String? customBoxName,
    String? customFilter,
  }) async {
    await CachingService.saveData(
      boxName: customBoxName ?? resolvedCacheBox,
      filter: customFilter ?? filter,
      data: data,
      clearId: clearId ?? clearIds,
      sortKey: sortKey,
    );
  }

  Future<void> clearCash([String? customBoxName]) async {
    await CachingService.clearCash(customBoxName ?? resolvedCacheBox);
  }

  Future<Iterable<dynamic>?> addOrUpdateDate(
    List<dynamic> data, {
    String? customBoxName,
    String? customFilter,
  }) async {
    return await CachingService.addOrUpdate(
      boxName: customBoxName ?? resolvedCacheBox,
      filter: customFilter ?? filter,
      data: data,
    );
  }

  Future<Iterable<dynamic>?> deleteDate(
    List<String> ids, {
    String? customBoxName,
    String? customFilter,
  }) async {
    return await CachingService.delete(
      boxName: customBoxName ?? resolvedCacheBox,
      filter: customFilter ?? filter,
      ids: ids,
    );
  }

  Future<List<T>> getListCached<T>({
    required T Function(Map<String, dynamic>) fromJson,
    bool? reversed,
    bool Function(Map<String, dynamic> json)? deleteFunction,
    String? customBoxName,
    String? customFilter,
  }) async {
    final data = await CachingService.getList(
      boxName: customBoxName ?? resolvedCacheBox,
      filter: customFilter ?? filter,
      deleteFunction: deleteFunction,
      reversed: reversed,
    );
    if (data.isEmpty) return <T>[];
    return data.map((e) {
      try {
        return fromJson(e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map));
      } catch (err) {
        _logger.e('convert json /$nameCache/: $err');
        return fromJson({});
      }
    }).toList();
  }

  Future<T> getDataCached<T>({
    required T Function(Map<String, dynamic>) fromJson,
    String? customBoxName,
    String? customFilter,
  }) async {
    final json = await CachingService.getData(
      boxName: customBoxName ?? resolvedCacheBox,
      filter: customFilter ?? filter,
    );
    final Map<String, dynamic> initial = {};
    try {
      if (json == null) return fromJson(initial);
      return fromJson(json is Map<String, dynamic> ? json : Map<String, dynamic>.from(json as Map));
    } catch (err) {
      _logger.e('convert json /$nameCache/: $err \n $json');
      return fromJson(initial);
    }
  }

  Future<MapEntry<bool, dynamic>> checkCashed<T>({
    dynamic state,
    required T Function(Map<String, dynamic>) fromJson,
    bool? newData,
    void Function(dynamic data, CubitStatuses emitState)? onSuccess,
  }) async {
    final currentState = state ?? this.state;
    dynamic data;

    if (currentState.result is List) {
      data = await getListCached<T>(fromJson: fromJson);
    } else {
      data = await getDataCached<T>(fromJson: fromJson);
    }

    final dynamic mState = (currentState as dynamic).copyWith(result: data);

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
      _logger.e('checkCashed $nameCache: $e');
      return MapEntry(false, mState);
    }
  }

  Future<void> getDataAbstract<T>({
    required T Function(Map<String, dynamic>) fromJson,
    dynamic state,
    required Function getDataApi,
    bool? newData,
    void Function(dynamic error)? onError,
    void Function(dynamic data, CubitStatuses emitState)? onSuccess,
  }) async {
    final currentFilter = filter;
    final currentBox = resolvedCacheBox;

    final checkData = await checkCashed<T>(
      state: state ?? this.state,
      fromJson: fromJson,
      newData: newData,
      onSuccess: onSuccess,
    );

    if (checkData.key) {
      _logger.f('$nameCache stopped on cache \n $currentFilter');
      return;
    }

    final dynamic pair = await getDataApi.call();
    final dynamic responseData = pair.first;
    final dynamic responseError = pair.second;

    if (responseData == null) {
      if (isClosed) return;
      final dynamic s = checkData.value.copyWith(
        statuses: CubitStatuses.error,
        error: responseError?.toString() ?? '',
      );
      emit(s);

      if (onError == null) {
        onErrorFun?.call(s);
      }
      onError?.call(responseError);
    } else {
      await saveData(
        responseData,
        customBoxName: currentBox,
        customFilter: currentFilter,
      );

      if (onSuccess != null) {
        onSuccess.call(responseData, CubitStatuses.done);
      } else {
        if (isClosed) return;
        emit(checkData.value.copyWith(statuses: CubitStatuses.done, result: responseData));
      }
    }
  }

  Future<dynamic> getAndSave<T>({
    required Function getDataApi,
  }) async {
    final dynamic pair = await getDataApi.call();
    if (pair.first == null) return null;
    await saveData(pair.first);
    return pair.first;
  }

  Future<dynamic> getFromCache<T>({
    required T Function(Map<String, dynamic>) fromJson,
    dynamic state,
    required void Function(dynamic data) onSuccess,
  }) async {
    final currentState = state ?? this.state;
    dynamic data;

    if (currentState.result is List) {
      data = await getListCached<T>(fromJson: fromJson);
    } else {
      data = await getDataCached<T>(fromJson: fromJson);
    }

    onSuccess.call(data);
    return data;
  }

  /// Modern helper to mutate and update local cache for items
  Future<List<T>?> addOrUpdateItems<T>({
    required List<dynamic> items,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final listJson = await addOrUpdateDate(items);
    if (listJson == null) return null;
    return listJson.map((e) => fromJson(e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map))).toList();
  }

  /// Modern helper to delete items by IDs and retrieve updated typed list
  Future<List<T>?> deleteItems<T>({
    required List<String> ids,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final listJson = await deleteDate(ids);
    if (listJson == null) return null;
    return listJson.map((e) => fromJson(e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map))).toList();
  }
}

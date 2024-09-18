import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:hive/hive.dart';
import 'package:m_cubit/util.dart';

import 'caching_service/caching_service.dart';
import 'command.dart';

enum CubitStatuses { init, loading, done, error }

abstract class AbstractState<T> extends Equatable {
  final CubitStatuses statuses;
  final String error;
  final T result;
  final FilterRequest? filterRequest;
  final dynamic request;

  String get filter => filterRequest?.getKey ?? request?.toString().getKey ?? '';

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

  Future<Box<String>> get box => CachingService.getBox(nameCache);

  Future<NeedUpdateEnum> _needGetData() async {
    return await CachingService.needGetData(this);
  }

  Future<void> storeData(dynamic data) async {
    loggerObject.f(filter);
    await CachingService.sortData(this, data: data);
  }

  Future<Iterable<dynamic>?> addOrUpdateDate(List<dynamic> data) async {
    return await CachingService.addOrUpdate(this, data: data);
  }

  Future<Iterable<dynamic>?> deleteDate(List<String> ids) async {
    return await CachingService.delete(this, ids: ids);
  }

  Future<List<T>> getListCached<T>({
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final data = await CachingService.getList(this);

    return data.map((e) {
      try {
        return fromJson(e);
      } catch (e) {
        return fromJson({});
      }
    }).toList();
  }

  Future<T> getDataCached<T>({
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final json = await CachingService.getData(this);
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
        data = await getDataCached(fromJson: fromJson);
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
      loggerObject.e('checkCashed  $nameCache: $e');

      return false;
    }
  }

  Future<void> getDataAbstract<T>({
    required T Function(Map<String, dynamic>) fromJson,
    required dynamic state,
    required Function getDataApi,
    bool newData = false,
    void Function(dynamic state)? onError,
    void Function(dynamic data, CubitStatuses emitState)? onSuccess,
  }) async {
    final checkData = await checkCashed(
      state: state,
      fromJson: fromJson,
      newData: newData,
      onSuccess: onSuccess,
    );

    if (checkData) {
      loggerObject.f('$nameCache stopped on cache');
      return;
    }

    final pair = await getDataApi.call();

    if (pair.first == null) {
      if (isClosed) return;

      final s = state.copyWith(statuses: CubitStatuses.error, error: pair.second);

      emit(s);

      onError?.call(pair.second);

    } else {

      await storeData(pair.first);

      if (onSuccess != null) {
        onSuccess.call(pair.first, CubitStatuses.done);
      } else {
        if (isClosed) return;
        emit(state.copyWith(statuses: CubitStatuses.done, result: pair.first));
      }
    }
  }
}

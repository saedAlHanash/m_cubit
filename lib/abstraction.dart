import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:caching_service/caching_service.dart';

enum CubitStatuses { init, loading, done, error }

abstract class AbstractState<T> extends Equatable {
  final CubitStatuses statuses;
  final String error;
  final T result;

  const AbstractState({
    this.statuses = CubitStatuses.init,
    this.error = '',
    required this.result,
  });
}

extension NeedUpdateEnumH on NeedUpdateEnum {
  bool get loading => this == NeedUpdateEnum.withLoading;

  bool get haveData =>
      this == NeedUpdateEnum.no || this == NeedUpdateEnum.noLoading;

  CubitStatuses get getState {
    switch (this) {
      case NeedUpdateEnum.no:
        return CubitStatuses.done;
      case NeedUpdateEnum.withLoading:
        return CubitStatuses.loading;
      case NeedUpdateEnum.noLoading:
        return CubitStatuses.done;
    }
  }
}

abstract class MCubit<AbstractState> extends Cubit<AbstractState> {
  MCubit(super.initialState);

  String get nameCache => '';

  String get filterKey => '';

  Future<NeedUpdateEnum> needGetData() async {
    if (nameCache.isEmpty) return NeedUpdateEnum.withLoading;
    return await CachingService.needGetData(nameCache, filterKey: filterKey);
  }

  Future<void> storeData(dynamic data) async {
    await CachingService.sortData(
        data: data, name: nameCache, filterKey: filterKey);
  }

  Future<Iterable<dynamic>> getListCached() async {
    final data = await CachingService.getList(nameCache, filterKey: filterKey);
    return data;
  }

  Future<dynamic> getDataCached() async {
    return (await CachingService.getData(nameCache, filterKey: filterKey)) ??
        <String, dynamic>{};
  }

  Future<bool> checkCashed1<T>({
    required dynamic state,
    required T Function(Map<String, dynamic>) fromJson,
    bool newData = false,
  }) async {
    if (newData) {
      emit(state.copyWith(statuses: CubitStatuses.loading));
      return false;
    }

    try {
      final cacheType = await needGetData();
      final emitState = cacheType.getState;
      dynamic data;

      if (state.result is List) {
        final listFromCash = (await getListCached());
        data = listFromCash.map((e) => fromJson(e)).toList();
      } else {
        data = fromJson(await getDataCached());
      }

      emit(
        state.copyWith(
          statuses: emitState,
          result: data,
        ),
      );

      if (cacheType == NeedUpdateEnum.no) return true;

      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> getDataAbstract<T>({
    required T Function(Map<String, dynamic>) fromJson,
    required dynamic state,
    required Function() getDataApi,
    bool newData = false,
    void Function()? onError,
    void Function()? onSuccess,
  }) async {
    final checkData = await checkCashed1(
      state: state,
      fromJson: fromJson,
      newData: newData,
    );

    if (checkData) return;

    final pair = await getDataApi.call();

    if (pair.first == null) {
      emit(state.copyWith(statuses: CubitStatuses.error, error: pair.second));
      onError?.call();
    } else {
      await storeData(pair.first);
      emit(state.copyWith(statuses: CubitStatuses.done, result: pair.first));
      onSuccess?.call();
    }
  }
}

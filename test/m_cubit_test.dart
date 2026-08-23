import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:m_cubit/m_cubit.dart';

class TestItem {
  final String id;
  final String name;

  const TestItem({required this.id, required this.name});

  factory TestItem.fromJson(Map<String, dynamic> json) {
    return TestItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class TestState extends AbstractState<List<TestItem>> {
  const TestState({
    required super.result,
    super.statuses,
    super.error,
    super.request,
  });

  factory TestState.initial() => const TestState(result: []);

  TestState copyWith({
    CubitStatuses? statuses,
    List<TestItem>? result,
    String? error,
    dynamic request,
  }) {
    return TestState(
      result: result ?? this.result,
      statuses: statuses ?? this.statuses,
      error: error ?? this.error,
      request: request ?? this.request,
    );
  }

  @override
  List<Object?> get props => [statuses, result, error, request];
}

class TestCubit extends MCubit<TestState> {
  TestCubit() : super(TestState.initial());

  @override
  String get nameCache => 'test_items';

  @override
  int get timeInterval => 2; // 2 seconds TTL for testing

  Future<void> loadData({bool newData = false, required List<TestItem> mockRemoteData}) async {
    await getDataAbstract<TestItem>(
      fromJson: TestItem.fromJson,
      newData: newData,
      getDataApi: () async => CachePair(mockRemoteData, null),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('mcubit_test_');
    await CachingService.initial(
      path: tempDir.path,
      version: 1,
      timeInterval: 2,
      onError: (_) {},
    );
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  test('MCubit Cache Flow with TTL and fallback', () async {
    final cubit = TestCubit();

    // 1. Initial fetch from remote
    final items1 = [const TestItem(id: '1', name: 'Item 1'), const TestItem(id: '2', name: 'Item 2')];
    await cubit.loadData(mockRemoteData: items1);

    expect(cubit.state.statuses, CubitStatuses.done);
    expect(cubit.state.result.length, 2);
    expect(cubit.state.result.first.name, 'Item 1');

    // 2. Fetch again immediately (TTL not expired) -> Should stop on cache
    final items2 = [const TestItem(id: '1', name: 'Updated Item')];
    await cubit.loadData(mockRemoteData: items2);

    // Result should remain items1 because it stopped on cache
    expect(cubit.state.result.first.name, 'Item 1');

    // 3. Mutate cache locally (addOrUpdateItems)
    final updated = await cubit.addOrUpdateItems<TestItem>(
      items: [const TestItem(id: '1', name: 'Manually Updated').toJson()],
      fromJson: TestItem.fromJson,
    );
    expect(updated?.first.name, 'Manually Updated');

    await cubit.close();
  });
}

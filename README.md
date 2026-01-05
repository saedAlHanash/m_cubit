# m_cubit Library

A powerful, opinionated caching layer for Flutter BLoC Cubits, designed to simplify state management by integrating seamless caching with repositories.

---

# مكتبة m_cubit

طبقة تخزين مؤقت قوية وموحدة لـ Cubits في Flutter BLoC، مصممة لتبسيط إدارة الحالة من خلال دمج التخزين المؤقت السلس مع مستودعات البيانات.

---

## English

### Core Features

-   **Automatic Caching:** Automatically caches data fetched from your repository, reducing redundant API calls.
-   **Time-based Expiration:** Control how long data remains cached with configurable time intervals.
-   **Declarative API:** A simple and abstract API to fetch, cache, and manage your data state.
-   **Filtering & Sorting:** Built-in support for server-side filtering and sorting requests.
-   **Offline First:** Serves cached data first when available, ensuring a smooth user experience even with poor connectivity.

### How It Works

`m_cubit` sits between your UI and your repository layer. When you request data, it first checks the cache.

```
+-----------+        +-----------------+        +------------------+
|           |        |                 |        |                  |
|    UI     |------->|     m_cubit     |------->|    Repository    |
|           |        | (Checks Cache)  |        | (Fetches from API|
|           |<-------|                 |<-------|    if needed)    |
|           |        |                 |        |                  |
+-----------+        +-----------------+        +------------------+
```

1.  **Request:** The UI requests data from an `MCubit`.
2.  **Cache Check:** `MCubit` asks the `CachingService` if valid, non-expired data for this request exists.
3.  **Return Cached Data:** If fresh data is found, it's returned immediately to the UI. The cubit can also decide if a background refresh is needed (`NeedUpdateEnum.noLoading`).
4.  **Fetch from Repository:** If no valid cache exists, the cubit calls the repository to fetch new data from the API.
5.  **Save & Return:** The new data is saved to the cache by `CachingService` and then returned to the UI.

### Usage Example

**1. Define Your State**

Your state must extend `AbstractState`.

```dart
// user_state.dart
import 'package:m_cubit/m_cubit.dart';

class UserState extends AbstractState<User> {
  const UserState({
    super.statuses = CubitStatuses.init,
    super.error = '',
    required super.result,
    super.id,
  });

  @override
  List<Object?> get props => [statuses, error, result, id];

  UserState copyWith({
    CubitStatuses? statuses,
    String? error,
    User? result,
    dynamic id,
  }) {
    return UserState(
      statuses: statuses ?? this.statuses,
      error: error ?? this.error,
      result: result ?? this.result,
      id: id ?? this.id,
    );
  }
}
```

**2. Create Your Cubit**

Your cubit must extend `MCubit`.

```dart
// user_cubit.dart
import 'package:m_cubit/m_cubit.dart';
import 'user_repository.dart';
import 'user_state.dart';

class UserCubit extends MCubit<UserState> {
  final UserRepository _userRepository;

  UserCubit(this._userRepository) : super(UserState(result: User()));

  // Define a unique cache name for this cubit's data
  @override
  String get nameCache => 'user';

  // Get the current filter/id from the state
  @override
  String get filter => state.id.toString();

  @override
  get mState => state;

  Future<void> getUser(String id, {bool newData = false}) async {
    final userState = state.copyWith(id: id);

    await getDataAbstract<User>(
      state: userState,
      fromJson: User.fromJson, // Function to convert JSON to your model
      newData: newData,
      getDataApi: () => _userRepository.getUser(id), // API call
    );
  }
}
```

**3. Initialize Caching Service**

Initialize the service in your `main.dart`.

```dart
// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CachingService.initial(onError: (error) {
    // Handle global caching errors
  });
  runApp(MyApp());
}
```

---

## العربية

### الميزات الأساسية

-   **تخزين مؤقت تلقائي:** يخزن البيانات التي يتم جلبها من المستودع تلقائيًا، مما يقلل من استدعاءات الواجهة البرمجية (API) المتكررة.
-   **صلاحية زمنية:** تحكم في مدة بقاء البيانات في ذاكرة التخزين المؤقت مع فترات زمنية قابلة للتكوين.
-   **واجهة برمجية تعريفية:** واجهة برمجية بسيطة ومجردة لجلب حالة البيانات وتخزينها مؤقتًا وإدارتها.
-   **الفلترة والترتيب:** دعم مدمج لطلبات الفلترة والترتيب من جانب الخادم.
-   **الأولوية للبيانات المحلية (Offline First):** يقدم البيانات المخزنة مؤقتًا أولاً عند توفرها، مما يضمن تجربة مستخدم سلسة حتى مع ضعف الاتصال.

### كيف تعمل المكتبة

تعمل `m_cubit` كطبقة وسيطة بين واجهة المستخدم (UI) وطبقة مستودع البيانات (Repository). عند طلب البيانات، تقوم أولاً بالتحقق من ذاكرة التخزين المؤقت.

```
+-----------+        +-----------------+        +------------------+
|           |        |                 |        |                  |
| واجهة    |------->|     m_cubit     |------->|      مستودع      |
| المستخدم |        | (يفحص الكاش)    |        | (يجلب من API عند |
|           |<-------|                 |<-------|      الحاجة)     |
|           |        |                 |        |                  |
+-----------+        +-----------------+        +------------------+
```

1.  **الطلب:** تطلب واجهة المستخدم البيانات من `MCubit`.
2.  **فحص ذاكرة التخزين المؤقت:** يسأل `MCubit` خدمة التخزين المؤقت `CachingService` عما إذا كانت هناك بيانات صالحة وغير منتهية الصلاحية لهذا الطلب.
3.  **إرجاع البيانات المخزنة:** إذا تم العثور على بيانات حديثة، يتم إرجاعها فورًا إلى واجهة المستخدم. يمكن للـ cubit أيضًا تحديد ما إذا كان التحديث في الخلفية مطلوبًا (`NeedUpdateEnum.noLoading`).
4.  **الجلب من المستودع:** في حالة عدم وجود ذاكرة تخزين مؤقت صالحة، يستدعي الـ cubit المستودع لجلب بيانات جديدة من الواجهة البرمجية.
5.  **الحفظ والإرجاع:** يتم حفظ البيانات الجديدة في ذاكرة التخزين المؤقت بواسطة `CachingService` ثم إرجاعها إلى واجهة المستخدم.

### مثال على الاستخدام

**١. تعريف الحالة (State)**

يجب أن ترث الحالة الخاصة بك من `AbstractState`.

```dart
// user_state.dart
import 'package:m_cubit/m_cubit.dart';

class UserState extends AbstractState<User> {
  const UserState({
    super.statuses = CubitStatuses.init,
    super.error = '',
    required super.result,
    super.id,
  });

  @override
  List<Object?> get props => [statuses, error, result, id];

  UserState copyWith({
    CubitStatuses? statuses,
    String? error,
    User? result,
    dynamic id,
  }) {
    return UserState(
      statuses: statuses ?? this.statuses,
      error: error ?? this.error,
      result: result ?? this.result,
      id: id ?? this.id,
    );
  }
}
```

**٢. إنشاء الـ Cubit**

يجب أن يرث الـ Cubit الخاص بك من `MCubit`.

```dart
// user_cubit.dart
import 'package:m_cubit/m_cubit.dart';
import 'user_repository.dart';
import 'user_state.dart';

class UserCubit extends MCubit<UserState> {
  final UserRepository _userRepository;

  UserCubit(this._userRepository) : super(UserState(result: User()));

  // تعريف اسم فريد للكاش لبيانات هذا الـ cubit
  @override
  String get nameCache => 'user';

  // الحصول على الفلتر/المعرف الحالي من الحالة
  @override
  String get filter => state.id.toString();

  @override
  get mState => state;

  Future<void> getUser(String id, {bool newData = false}) async {
    final userState = state.copyWith(id: id);

    await getDataAbstract<User>(
      state: userState,
      fromJson: User.fromJson, // دالة لتحويل JSON إلى النموذج الخاص بك
      newData: newData,
      getDataApi: () => _userRepository.getUser(id), // استدعاء الواجهة البرمجية
    );
  }
}
```

**٣. تهيئة خدمة التخزين المؤقت**

قم بتهيئة الخدمة في ملف `main.dart` الخاص بك.

```dart
// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CachingService.initial(onError: (error) {
    // معالجة أخطاء التخزين المؤقت العامة
  });
  runApp(MyApp());
}
```

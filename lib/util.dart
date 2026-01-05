// استيراد المكتبات اللازمة
import 'abstraction.dart';

// اتجاه الترتيب
enum FilterOrderBy {
  desc, // تنازلي
  asc, // تصاعدي
}

// عمليات الفلترة
enum FilterOperation {
  equals('Equals'), // يساوي
  notEqual('NotEqual'), // لا يساوي
  contains('Contains'), // يحتوي على
  startsWith('StartsWith'), // يبدأ بـ
  endsWith('EndsWith'), // ينتهي بـ
  lessThan('LessThan'), // أصغر من
  lessThanEqual('LessThanEqual'), // أصغر من أو يساوي
  greaterThan('GreaterThan'), // أكبر من
  greaterThanEqual('GreaterThanEqual'); // أكبر من أو يساوي

  const FilterOperation(this.realName);

  final String realName;

  // الحصول على العملية بالاسم
  static FilterOperation byName(String s) {
    switch (s) {
      case 'Equals':
        return FilterOperation.equals;
      case 'NotEqual':
        return FilterOperation.notEqual;
      case 'Contains':
        return FilterOperation.contains;
      case 'StartsWith':
        return FilterOperation.startsWith;
      case 'EndsWith':
        return FilterOperation.endsWith;
      case 'LessThan':
        return FilterOperation.lessThan;
      case 'LessThanEqual':
        return FilterOperation.lessThanEqual;
      case 'GreaterThan':
        return FilterOperation.greaterThan;
      case 'GreaterThanEqual':
        return FilterOperation.greaterThanEqual;
      default:
        return FilterOperation.equals;
    }
  }
}

// حالات الحاجة إلى تحديث
enum NeedUpdateEnum { no, withLoading, noLoading }

// امتدادات مساعدة للسلاسل النصية
extension McubitStringH on String {
  // تحديد أقصى طول للسلسلة النصية
  String maxLength(int l) {
    if (length > l) return substring(0, l);
    return this;
  }

  // الحصول على مفتاح فريد
  String get getKey {
    // var bytes = utf8.encode(this);
    // var digest = md5.convert(bytes);
    // var digest1 = sha1.convert(bytes);
    var digest2 = hashCode.toString();

    return digest2.maxLength(10);
  }
}

// امتدادات مساعدة للسلاسل النصية القابلة للإلغاء
extension StringHelper on String? {
  // التحقق مما إذا كانت السلسلة النصية فارغة
  bool get isBlank {
    if (this == null) return true;
    if (this == 'null') return true;
    return this!.trim().isEmpty;
  }
}

// امتدادات مساعدة لحالات الحاجة إلى تحديث
extension NeedUpdateEnumH on NeedUpdateEnum {
  // التحقق مما إذا كان هناك تحميل
  bool get loading => this == NeedUpdateEnum.withLoading;

  // التحقق مما إذا كانت هناك بيانات
  bool get haveData => this == NeedUpdateEnum.no || this == NeedUpdateEnum.noLoading;

  // الحصول على حالة Cubit
  CubitStatuses get getState {
    switch (this) {
      case NeedUpdateEnum.no:
        return CubitStatuses.done;
      case NeedUpdateEnum.withLoading:
        return CubitStatuses.loading;
      case NeedUpdateEnum.noLoading:
        return CubitStatuses.noLoading;
    }
  }
}

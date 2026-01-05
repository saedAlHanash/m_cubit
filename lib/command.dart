// استيراد المكتبات اللازمة
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:m_cubit/util.dart';

// طلب فلترة البيانات
class FilterRequest {
  FilterRequest({
    Map<String, Filter>? filters,
    List<OrderBy>? orderBy,
    this.pageableQuery,
    this.tripId,
    this.memberId,
  })  : filters = filters ?? {},
        orderBy = orderBy ?? [];

  Map<String, Filter> filters = {};
  List<OrderBy> orderBy = [];
  PageableQuery? pageableQuery;
  String? tripId;
  String? memberId;

  // إضافة فلتر جديد
  void addFilter(Filter f) {
    filters[f.name] = f;
  }

  // التحقق مما إذا كانت البيانات مرتبة
  bool get isSorted => orderBy.isNotEmpty == true;

  // عدد حقول الترتيب
  int get sortedCount => orderBy.length;

  // التحقق مما إذا كانت البيانات مفلترة
  bool get isFiltered => filters.isNotEmpty == true;

  // عدد الفلاتر المطبقة
  int get filteredCount => filters.length;

  // التحقق مما إذا كان هناك بحث بالاسم
  bool get isSearch => isFiltered && filters.keys.firstWhereOrNull((e) => e.toLowerCase().contains('name')) != null;

  // تحويل الكائن إلى JSON
  Map<String, dynamic> toJson() => {
        "filters": filters.values.map((x) {
          if (x.name.startsWith('_')) {
            x.name = x.name.replaceFirst('_', '');
          }
          return x.toJson();
        }).toList(),
        "orderBy": orderBy.map((x) => x.toJson()).toList(),
        "pageableQuery": pageableQuery?.toJson(),
        "tripId": tripId,
        "memberId": memberId,
      };

  // الحصول على مفتاح فريد للطلب
  String get getKey {
    return jsonEncode(this).getKey;
  }

  // البحث عن مفتاح الترتيب
  FilterOrderBy? findOrderKey(String id) => orderBy.firstWhereOrNull((e) => e.attribute == id)?.direction;
}

// فلتر البيانات
class Filter {
  Filter({
    required this.name,
    required this.val,
    this.operation = FilterOperation.equals,
  });

  String name;
  final String val;
  final FilterOperation operation;

  // إنشاء كائن من JSON
  factory Filter.fromJson(Map<String, dynamic> json) {
    return Filter(
      name: json["name"] ?? "",
      val: json["val"] ?? "",
      operation: FilterOperation.byName(json["operation"] ?? ''),
    );
  }

  // تحويل الكائن إلى JSON
  Map<String, dynamic> toJson() => {
        "name": name,
        "val": val,
        "operation": operation.realName,
      };
}

// ترتيب البيانات
class OrderBy {
  OrderBy({
    required this.attribute,
    required this.direction,
  });

  final String attribute;
  final FilterOrderBy direction;

  // إنشاء كائن من JSON
  factory OrderBy.fromJson(Map<String, dynamic> json) {
    return OrderBy(
      attribute: json["attribute"] ?? "",
      direction: FilterOrderBy.values[(json["direction"] ?? 0)],
    );
  }

  // تحويل الكائن إلى JSON
  Map<String, dynamic> toJson() => {
        "attribute": attribute,
        "direction": direction.name,
      };
}

// استعلام لتقسيم البيانات إلى صفحات
class PageableQuery {
  PageableQuery({
    required this.pageNumer,
    required this.pageSize,
  });

  final num pageNumer;
  final num pageSize;

  // إنشاء كائن من JSON
  factory PageableQuery.fromJson(Map<String, dynamic> json) {
    return PageableQuery(
      pageNumer: json["pageNumer"] ?? 0,
      pageSize: json["pageSize"] ?? 0,
    );
  }

  // تحويل الكائن إلى JSON
  Map<String, dynamic> toJson() => {
        "pageNumer": pageNumer,
        "pageSize": pageSize,
      };
}

// معلومات تقسيم الصفحات
class PaginationMeta {
  PaginationMeta({
    required this.currentPage,
    required this.lastPage,
    this.perPage = 20,
    required this.total,
  });

  int currentPage;
  final int lastPage;
  int perPage;
  final int total;

  // التحقق من وجود صفحة تالية
  bool get haveNext => currentPage < lastPage;

  // إنشاء كائن من JSON
  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    return PaginationMeta(
      currentPage: json["current_page"] ?? 0,
      lastPage: json["last_page"] ?? 0,
      perPage: json["per_page"] ?? 20,
      total: json["total"] ?? 0,
    );
  }

  // الانتقال إلى الصفحة التالية
  PaginationMeta get next => this..currentPage += 1;

  // تحويل الكائن إلى JSON
  Map<String, dynamic> toJson() => {
        "current_page": currentPage,
        "last_page": lastPage,
        "per_page": perPage,
        "total": total,
      };

  // تحويل الكائن إلى JSON للصفحة التالية
  Map<String, dynamic> toJsonNext() => {
        "current_page": currentPage,
        "per_page": perPage,
      };
}

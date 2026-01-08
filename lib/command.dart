// import 'dart:convert';
//
// import 'package:collection/collection.dart';
// import 'package:m_cubit/util.dart';
//
// class FilterRequest {
//   FilterRequest({
//     Map<String, Filter>? filters,
//     List<OrderBy>? orderBy,
//     this.pageableQuery,
//     this.tripId,
//     this.memberId,
//   })  : filters = filters ?? {},
//         orderBy = orderBy ?? [];
//
//   Map<String, Filter> filters = {};
//   List<OrderBy> orderBy = [];
//   PageableQuery? pageableQuery;
//   String? tripId;
//   String? memberId;
//
//   void addFilter(Filter f) {
//     filters[f.name] = f;
//   }
//
//   bool get isSorted => orderBy.isNotEmpty == true;
//
//   int get sortedCount => orderBy.length;
//
//   bool get isFiltered => filters.isNotEmpty == true;
//
//   int get filteredCount => filters.length;
//
//   bool get isSearch => isFiltered && filters.keys.firstWhereOrNull((e) => e.toLowerCase().contains('name')) != null;
//
//   Map<String, dynamic> toJson() => {
//         "filters": filters.values.map((x) {
//           if (x.name.startsWith('_')) {
//             x.name = x.name.replaceFirst('_', '');
//           }
//           return x.toJson();
//         }).toList(),
//         "orderBy": orderBy.map((x) => x.toJson()).toList(),
//         "pageableQuery": pageableQuery?.toJson(),
//         "tripId": tripId,
//         "memberId": memberId,
//       };
//
//   String get getKey {
//     return jsonEncode(this).getKey;
//   }
//
//   FilterOrderBy? findOrderKey(String id) => orderBy.firstWhereOrNull((e) => e.attribute == id)?.direction;
// }
//
// class Filter {
//   Filter({
//     required this.name,
//     required this.val,
//     this.operation = FilterOperation.equals,
//   });
//
//   String name;
//   final String val;
//   final FilterOperation operation;
//
//   factory Filter.fromJson(Map<String, dynamic> json) {
//     return Filter(
//       name: json["name"] ?? "",
//       val: json["val"] ?? "",
//       operation: FilterOperation.byName(json["operation"] ?? ''),
//     );
//   }
//
//   Map<String, dynamic> toJson() => {
//         "name": name,
//         "val": val,
//         "operation": operation.realName,
//       };
// }
//
// class OrderBy {
//   OrderBy({
//     required this.attribute,
//     required this.direction,
//   });
//
//   final String attribute;
//   final FilterOrderBy direction;
//
//   factory OrderBy.fromJson(Map<String, dynamic> json) {
//     return OrderBy(
//       attribute: json["attribute"] ?? "",
//       direction: FilterOrderBy.values[(json["direction"] ?? 0)],
//     );
//   }
//
//   Map<String, dynamic> toJson() => {
//         "attribute": attribute,
//         "direction": direction.name,
//       };
// }
//
// class PageableQuery {
//   PageableQuery({
//     required this.pageNumer,
//     required this.pageSize,
//   });
//
//   final num pageNumer;
//   final num pageSize;
//
//   factory PageableQuery.fromJson(Map<String, dynamic> json) {
//     return PageableQuery(
//       pageNumer: json["pageNumer"] ?? 0,
//       pageSize: json["pageSize"] ?? 0,
//     );
//   }
//
//   Map<String, dynamic> toJson() => {
//         "pageNumer": pageNumer,
//         "pageSize": pageSize,
//       };
// }
//
// class PaginationMeta {
//   PaginationMeta({
//     required this.currentPage,
//     required this.lastPage,
//     this.perPage = 20,
//     required this.total,
//   });
//
//   int currentPage;
//   final int lastPage;
//   int perPage;
//   final int total;
//
//   bool get haveNext => currentPage < lastPage;
//
//   String get getKey => '$currentPage$perPage'.hashCode.toString();
//
//   factory PaginationMeta.fromJson(Map<String, dynamic> json) {
//     return PaginationMeta(
//       currentPage: json["current_page"] ?? 0,
//       lastPage: json["last_page"] ?? 0,
//       perPage: json["per_page"] ?? 20,
//       total: json["total"] ?? 0,
//     );
//   }
//
//   PaginationMeta get next => this..currentPage += 1;
//
//   Map<String, dynamic> toJson() => {
//         "current_page": currentPage,
//         "last_page": lastPage,
//         "per_page": perPage,
//         "total": total,
//       };
//
//   Map<String, dynamic> toJsonNext() => {
//         "current_page": currentPage,
//         "per_page": perPage,
//       };
// }

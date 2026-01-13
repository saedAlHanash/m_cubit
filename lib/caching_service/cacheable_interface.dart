// import 'dart:convert';
//
// import 'caching_service.dart';
//
// abstract class CacheableInterface<T> {
//   // لازم الابن يمرر factory تبعه
//   T Function(Map<String, dynamic>) get fromJsonFactory;
//
//   // اسم الكاش
//   static String get nameCache => '';
//
//   // الابن يحوّل نفسه إلى json
//   Map<String, dynamic> toJson();
//
//   // ---- منطق مشترك ----
//
//   T get fromCache {
//     final json = CachingService.getFromBucketJsonSync(key: nameCache);
//     return fromJsonFactory(json);
//   }
//
//   Future<void> saveToCache() async {
//     await CachingService.addInBucketJson(
//       key: nameCache,
//       jsonEncode: jsonEncode(toJson()),
//     );
//   }
// }

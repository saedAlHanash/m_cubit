class PaginationMeta {
  PaginationMeta({
    required this.currentPage,
    required this.perPage,
    required this.lastPage,
    required this.total,
  });

  int currentPage;
  int perPage;
  final int lastPage;
  final int total;

  bool get haveNext => currentPage < lastPage;

  PaginationMeta get next => this..currentPage += 1;

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    return PaginationMeta(
      currentPage: json["page"] ?? 0,
      lastPage: json["lastPage"] ?? 0,
      perPage: json["perPage"] ?? 0,
      total: json["total"] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        "page": currentPage,
        "lastPage": lastPage,
        "perPage": perPage,
        "total": total,
      };
}

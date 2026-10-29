abstract interface class CatalogEntity {
  int get id;
  String get label;
  DateTime? get deletedAt;
  bool get isDeleted;
  Map<String, dynamic> toJson();
}

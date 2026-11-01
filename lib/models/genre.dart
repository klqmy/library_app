import 'catalog_entity.dart';
import 'json_values.dart';

class Genre implements CatalogEntity {
  @override
  final int id;
  final String name;
  final String description;
  @override
  final DateTime? deletedAt;
  const Genre({
    required this.id,
    required this.name,
    required this.description,
    this.deletedAt,
  });
  @override
  String get label => name;
  @override
  bool get isDeleted => deletedAt != null;
  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'deletedAt': deletedAt?.toUtc().toIso8601String(),
  };
  factory Genre.fromJson(Map<String, dynamic> json) => Genre(
    id: jsonInt(json['id']),
    name: jsonString(json['name']),
    description: jsonString(json['description']),
    deletedAt: jsonDate(json['deletedAt']),
  );
}

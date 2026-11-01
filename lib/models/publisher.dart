import 'catalog_entity.dart';
import 'json_values.dart';

class Publisher implements CatalogEntity {
  @override
  final int id;
  final String name;
  final String city;
  final int? foundedYear;
  @override
  final DateTime? deletedAt;
  const Publisher({
    required this.id,
    required this.name,
    required this.city,
    this.foundedYear,
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
    'city': city,
    'foundedYear': foundedYear,
    'deletedAt': deletedAt?.toUtc().toIso8601String(),
  };
  factory Publisher.fromJson(Map<String, dynamic> json) => Publisher(
    id: jsonInt(json['id']),
    name: jsonString(json['name']),
    city: jsonString(json['city']),
    foundedYear: jsonOptionalInt(json['foundedYear']),
    deletedAt: jsonDate(json['deletedAt']),
  );
}

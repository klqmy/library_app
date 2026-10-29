import 'catalog_entity.dart';
import 'json_values.dart';

class Publisher implements CatalogEntity {
  @override
  final int id;
  final String name;
  final String country;
  final String city;
  final List<int> genreIds;
  @override
  final DateTime? deletedAt;
  const Publisher({
    required this.id,
    required this.name,
    required this.country,
    required this.city,
    required this.genreIds,
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
    'country': country,
    'city': city,
    'genreIds': genreIds,
    'deletedAt': deletedAt?.toIso8601String(),
  };
  factory Publisher.fromJson(Map<String, dynamic> json) => Publisher(
    id: jsonInt(json['id']),
    name: jsonString(json['name']),
    country: jsonString(json['country']),
    city: jsonString(json['city']),
    genreIds: jsonIds(json['genreIds']),
    deletedAt: jsonDate(json['deletedAt']),
  );
}

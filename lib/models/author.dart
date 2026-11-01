import 'catalog_entity.dart';
import 'json_values.dart';

class Author implements CatalogEntity {
  @override
  final int id;
  final String fullName;
  final int? birthYear;
  final String country;
  @override
  final DateTime? deletedAt;

  const Author({
    required this.id,
    required this.fullName,
    this.birthYear,
    required this.country,
    this.deletedAt,
  });

  @override
  String get label => fullName;

  @override
  bool get isDeleted => deletedAt != null;

  Author copyWith({
    String? fullName,
    int? birthYear,
    String? country,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Author(
      id: id,
      fullName: fullName ?? this.fullName,
      birthYear: birthYear ?? this.birthYear,
      country: country ?? this.country,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'birthYear': birthYear,
    'country': country,
    'deletedAt': deletedAt?.toUtc().toIso8601String(),
  };

  factory Author.fromJson(Map<String, dynamic> json) => Author(
    id: jsonInt(json['id']),
    fullName: jsonFullName(json),
    birthYear: jsonOptionalInt(json['birthYear']),
    country: jsonString(json['country']),
    deletedAt: jsonDate(json['deletedAt']),
  );
}

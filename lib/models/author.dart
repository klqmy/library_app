import 'catalog_entity.dart';
import 'json_values.dart';

class Author implements CatalogEntity {
  @override
  final int id;
  final String firstName;
  final String lastName;
  final String country;
  @override
  final DateTime? deletedAt;

  const Author({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.country,
    this.deletedAt,
  });

  @override
  String get label => fullName;

  @override
  bool get isDeleted => deletedAt != null;
  String get fullName => '$lastName $firstName';

  Author copyWith({
    String? firstName,
    String? lastName,
    String? country,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Author(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      country: country ?? this.country,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'firstName': firstName,
    'lastName': lastName,
    'country': country,
    'deletedAt': deletedAt?.toIso8601String(),
  };

  factory Author.fromJson(Map<String, dynamic> json) => Author(
    id: jsonInt(json['id']),
    firstName: jsonString(json['firstName']),
    lastName: jsonString(json['lastName']),
    country: jsonString(json['country']),
    deletedAt: jsonDate(json['deletedAt']),
  );
}
